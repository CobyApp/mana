// Minimal language switcher. Persists selection in localStorage and
// honors ?lang= override (useful for App Store deep-linking).
(function () {
  const supported = ["ja", "ko", "en"];
  const defaultLang = "ja";

  function detect() {
    const param = new URLSearchParams(location.search).get("lang");
    if (param && supported.includes(param)) return param;

    const stored = localStorage.getItem("noiz.lang");
    if (stored && supported.includes(stored)) return stored;

    const nav = (navigator.language || "").toLowerCase();
    if (nav.startsWith("ja")) return "ja";
    if (nav.startsWith("ko")) return "ko";
    if (nav.startsWith("en")) return "en";
    return defaultLang;
  }

  function apply(lang) {
    document.documentElement.lang = lang;
    localStorage.setItem("noiz.lang", lang);
    document.querySelectorAll(".lang-switcher button").forEach((b) => {
      b.setAttribute("aria-pressed", b.dataset.lang === lang ? "true" : "false");
    });
  }

  document.addEventListener("DOMContentLoaded", function () {
    apply(detect());
    document.querySelectorAll(".lang-switcher button").forEach((b) => {
      b.addEventListener("click", () => apply(b.dataset.lang));
    });
  });
})();
