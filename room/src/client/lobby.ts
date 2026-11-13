import { isValidRoomCode } from "../shared/protocol";

const NAME_KEY = "study-room-name";

function randomCode(): string {
  const letters = "abcdefghijkmnpqrstuvwxyz";
  const pick = (n: number) => Array.from(crypto.getRandomValues(new Uint8Array(n)), (b) => letters[b % letters.length]).join("");
  return `${pick(3)}-${pick(4)}-${pick(3)}`;
}

const form = document.getElementById("lobby") as HTMLFormElement;
const nameInput = document.getElementById("name") as HTMLInputElement;
const codeInput = document.getElementById("code") as HTMLInputElement;

try {
  nameInput.value = localStorage.getItem(NAME_KEY) ?? "";
} catch {}
codeInput.value = randomCode();

form.addEventListener("submit", (event) => {
  event.preventDefault();
  const code = codeInput.value.trim().toLowerCase();
  if (!isValidRoomCode(code)) {
    codeInput.setCustomValidity("Use 3–40 lowercase letters, digits and dashes.");
    codeInput.reportValidity();
    return;
  }
  try {
    localStorage.setItem(NAME_KEY, nameInput.value.trim());
  } catch {}
  location.href = `/r/${encodeURIComponent(code)}`;
});
codeInput.addEventListener("input", () => codeInput.setCustomValidity(""));
