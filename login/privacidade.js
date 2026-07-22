const progressBar = document.getElementById("privacy-progress");
const tocLinks = Array.from(document.querySelectorAll(".privacy-toc-list a"));
const topButton = document.getElementById("privacy-top");
const tocToggle = document.getElementById("privacy-toc-toggle");
const toc = document.getElementById("privacy-toc");

function updateReadingProgress() {
    if (!progressBar) return;

    const scrollTop = window.scrollY;
    const docHeight = document.documentElement.scrollHeight - window.innerHeight;
    const progress = docHeight > 0 ? Math.min(Math.max(scrollTop / docHeight, 0), 1) : 0;
    progressBar.style.transform = `scaleX(${progress})`;
}

function updateTopButton() {
    if (!topButton) return;
    topButton.hidden = window.scrollY < 320;
}

function onScroll() {
    updateReadingProgress();
    updateTopButton();
}

tocLinks.forEach((link) => {
    link.addEventListener("click", () => {
        if (window.matchMedia("(max-width: 899px)").matches && toc) {
            toc.classList.remove("is-open");
            tocToggle?.setAttribute("aria-expanded", "false");
        }
    });
});

tocToggle?.addEventListener("click", () => {
    const isOpen = toc?.classList.toggle("is-open");
    tocToggle.setAttribute("aria-expanded", isOpen ? "true" : "false");
});

topButton?.addEventListener("click", () => {
    window.scrollTo({ top: 0, behavior: "smooth" });
});

window.addEventListener("scroll", onScroll, { passive: true });
window.addEventListener("resize", onScroll);
onScroll();
