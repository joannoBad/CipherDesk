const form = document.querySelector("#crypto-form");
const passwordInput = document.querySelector("#password");
const inputText = document.querySelector("#input-text");
const outputText = document.querySelector("#output-text");
const statusText = document.querySelector("#status-text");
const copyButton = document.querySelector("#copy-button");
const clearButton = document.querySelector("#clear-button");
const submitButton = document.querySelector("#submit-button");
const inputLabel = document.querySelector("#input-label");
const tabs = Array.from(document.querySelectorAll(".tab"));

const textEncoder = new TextEncoder();
const textDecoder = new TextDecoder();

let mode = "encrypt";

tabs.forEach((tab) => {
  tab.addEventListener("click", () => {
    mode = tab.dataset.mode;

    tabs.forEach((item) => item.classList.toggle("is-active", item === tab));

    if (mode === "encrypt") {
      inputLabel.textContent = "Исходный текст";
      inputText.placeholder = "Введите текст для шифрования";
      submitButton.textContent = "Зашифровать";
      statusText.textContent = "Режим шифрования";
    } else {
      inputLabel.textContent = "Зашифрованная строка";
      inputText.placeholder = "Вставьте строку в формате JSON";
      submitButton.textContent = "Расшифровать";
      statusText.textContent = "Режим расшифровки";
    }

    outputText.value = "";
  });
});

form.addEventListener("submit", async (event) => {
  event.preventDefault();

  const password = passwordInput.value.trim();
  const payload = inputText.value.trim();

  if (!password || !payload) {
    setStatus("Заполните пароль и текст.", true);
    return;
  }

  try {
    setBusy(true);

    if (mode === "encrypt") {
      outputText.value = await encryptText(payload, password);
      setStatus("Текст успешно зашифрован.");
    } else {
      outputText.value = await decryptText(payload, password);
      setStatus("Текст успешно расшифрован.");
    }
  } catch (error) {
    setStatus(error.message || "Не удалось выполнить операцию.", true);
  } finally {
    setBusy(false);
  }
});

copyButton.addEventListener("click", async () => {
  if (!outputText.value) {
    setStatus("Сначала получите результат.", true);
    return;
  }

  try {
    if (navigator.clipboard?.writeText) {
      await navigator.clipboard.writeText(outputText.value);
    } else {
      outputText.removeAttribute("readonly");
      outputText.select();
      document.execCommand("copy");
      outputText.setAttribute("readonly", "readonly");
    }

    setStatus("Результат скопирован в буфер обмена.");
  } catch (_error) {
    setStatus("Не удалось скопировать результат.", true);
  }
});

clearButton.addEventListener("click", () => {
  form.reset();
  inputText.value = "";
  outputText.value = "";
  setStatus("Поля очищены.");
});

function setBusy(isBusy) {
  submitButton.disabled = isBusy;
  submitButton.textContent = isBusy
    ? mode === "encrypt"
      ? "Шифруем..."
      : "Расшифровываем..."
    : mode === "encrypt"
      ? "Зашифровать"
      : "Расшифровать";
}

function setStatus(message, isError = false) {
  statusText.textContent = message;
  statusText.style.color = isError ? "#b42318" : "#2e7d57";
}

async function encryptText(plainText, password) {
  const salt = crypto.getRandomValues(new Uint8Array(16));
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const key = await deriveKey(password, salt);
  const encrypted = await crypto.subtle.encrypt(
    { name: "AES-GCM", iv },
    key,
    textEncoder.encode(plainText)
  );

  return JSON.stringify({
    algorithm: "AES-GCM",
    kdf: "PBKDF2",
    iterations: 250000,
    salt: toBase64(salt),
    iv: toBase64(iv),
    data: toBase64(new Uint8Array(encrypted)),
  }, null, 2);
}

async function decryptText(serializedPayload, password) {
  let parsed;

  try {
    parsed = JSON.parse(serializedPayload);
  } catch (_error) {
    throw new Error("Неверный формат. Ожидается JSON-строка из режима шифрования.");
  }

  if (!parsed?.salt || !parsed?.iv || !parsed?.data) {
    throw new Error("В зашифрованных данных не хватает salt, iv или data.");
  }

  const salt = fromBase64(parsed.salt);
  const iv = fromBase64(parsed.iv);
  const data = fromBase64(parsed.data);
  const key = await deriveKey(password, salt, parsed.iterations || 250000);

  try {
    const decrypted = await crypto.subtle.decrypt(
      { name: "AES-GCM", iv },
      key,
      data
    );

    return textDecoder.decode(decrypted);
  } catch (_error) {
    throw new Error("Не удалось расшифровать данные. Проверьте пароль и содержимое.");
  }
}

async function deriveKey(password, salt, iterations = 250000) {
  const baseKey = await crypto.subtle.importKey(
    "raw",
    textEncoder.encode(password),
    "PBKDF2",
    false,
    ["deriveKey"]
  );

  return crypto.subtle.deriveKey(
    {
      name: "PBKDF2",
      salt,
      iterations,
      hash: "SHA-256",
    },
    baseKey,
    {
      name: "AES-GCM",
      length: 256,
    },
    false,
    ["encrypt", "decrypt"]
  );
}

function toBase64(bytes) {
  return btoa(String.fromCharCode(...bytes));
}

function fromBase64(value) {
  return Uint8Array.from(atob(value), (char) => char.charCodeAt(0));
}
