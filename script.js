const menuToggle = document.querySelector(".menu-toggle");
const navLinks = document.querySelector(".nav-links");
const navItems = document.querySelectorAll(".nav-links a");

if (menuToggle && navLinks) {
  const closeMenu = () => {
    navLinks.classList.remove("open");
    menuToggle.setAttribute("aria-expanded", "false");
    menuToggle.setAttribute("aria-label", "Mở menu");
  };

  menuToggle.addEventListener("click", () => {
    const isOpen = navLinks.classList.toggle("open");
    menuToggle.setAttribute("aria-expanded", String(isOpen));
    menuToggle.setAttribute("aria-label", isOpen ? "Đóng menu" : "Mở menu");
  });

  navItems.forEach((item) => item.addEventListener("click", closeMenu));

  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape") {
      closeMenu();
    }
  });
}

const filterButtons = document.querySelectorAll(".filter-button");
const projectCards = document.querySelectorAll(".project-card");

filterButtons.forEach((button) => {
  button.setAttribute("aria-pressed", String(button.classList.contains("active")));
  button.addEventListener("click", () => {
    const filter = button.dataset.filter;
    if (!filter) {
      return;
    }

    filterButtons.forEach((item) => {
      const isActive = item === button;
      item.classList.toggle("active", isActive);
      item.setAttribute("aria-pressed", String(isActive));
    });

    projectCards.forEach((card) => {
      const visible = filter === "all" || card.dataset.category === filter;
      card.classList.toggle("hidden", !visible);
    });
  });
});

document.querySelectorAll(".print-button").forEach((button) => {
  button.addEventListener("click", () => window.print());
});

const year = document.getElementById("year");
if (year) {
  year.textContent = String(new Date().getFullYear());
}

const reducedMotion = window.matchMedia
  ? window.matchMedia("(prefers-reduced-motion: reduce)").matches
  : false;
const revealItems = document.querySelectorAll(".reveal");

if (reducedMotion || !("IntersectionObserver" in window)) {
  revealItems.forEach((item) => item.classList.add("visible"));
} else if (revealItems.length > 0) {
  document.documentElement.classList.add("js-ready");
  const revealObserver = new IntersectionObserver((entries, observer) => {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        entry.target.classList.add("visible");
        observer.unobserve(entry.target);
      }
    });
  }, { threshold: 0.12 });
  revealItems.forEach((item) => revealObserver.observe(item));
}

const finePointer = window.matchMedia
  && window.matchMedia("(hover: hover) and (pointer: fine)").matches;

if (!reducedMotion && finePointer) {
  const heroArt = document.querySelector(".hero-art");
  if (heroArt) {
    let pointerFrame = 0;
    let pointerX = 0;
    let pointerY = 0;

    heroArt.addEventListener("pointermove", (event) => {
      pointerX = event.clientX;
      pointerY = event.clientY;
      if (pointerFrame) {
        return;
      }

      pointerFrame = window.requestAnimationFrame(() => {
        const bounds = heroArt.getBoundingClientRect();
        const x = (pointerX - bounds.left) / bounds.width - 0.5;
        const y = (pointerY - bounds.top) / bounds.height - 0.5;
        heroArt.style.transform = `rotate(2deg) translate3d(${x * 8}px, ${y * 8}px, 0)`;
        pointerFrame = 0;
      });
    });

    heroArt.addEventListener("pointerleave", () => {
      if (pointerFrame) {
        window.cancelAnimationFrame(pointerFrame);
        pointerFrame = 0;
      }
      heroArt.style.transform = "";
    });
  }

  document.querySelectorAll(".project-card").forEach((card) => {
    let tiltFrame = 0;
    let pointerX = 0;
    let pointerY = 0;

    card.addEventListener("pointermove", (event) => {
      pointerX = event.clientX;
      pointerY = event.clientY;
      if (tiltFrame) {
        return;
      }

      tiltFrame = window.requestAnimationFrame(() => {
        const bounds = card.getBoundingClientRect();
        const x = (pointerX - bounds.left) / bounds.width - 0.5;
        const y = (pointerY - bounds.top) / bounds.height - 0.5;
        card.style.transform = `perspective(900px) rotateX(${y * -3}deg) rotateY(${x * 3}deg) translateY(-3px)`;
        tiltFrame = 0;
      });
    });

    card.addEventListener("pointerleave", () => {
      if (tiltFrame) {
        window.cancelAnimationFrame(tiltFrame);
        tiltFrame = 0;
      }
      card.style.transform = "";
    });
  });
}

document.querySelectorAll('a[href^="#"]').forEach((link) => {
  link.addEventListener("click", (event) => {
    const hash = link.getAttribute("href");
    const target = hash ? document.querySelector(hash) : null;
    if (!target) {
      return;
    }

    event.preventDefault();
    window.history.pushState(null, "", hash);
    target.scrollIntoView({
      behavior: reducedMotion ? "auto" : "smooth",
      block: "start"
    });
  });
});

document.querySelectorAll('a[href$=".html"]').forEach((link) => {
  link.addEventListener("click", (event) => {
    if (
      event.defaultPrevented
      || event.button !== 0
      || event.metaKey
      || event.ctrlKey
      || event.shiftKey
      || event.altKey
      || link.target
      || link.hasAttribute("download")
    ) {
      return;
    }

    const destination = new URL(link.href, window.location.href);
    if (destination.origin !== window.location.origin) {
      return;
    }

    document.body.classList.add("page-transition");
    window.setTimeout(() => document.body.classList.remove("page-transition"), 350);
  });
});

const contactForm = document.getElementById("contactForm");
if (contactForm) {
  const formStatus = document.getElementById("formStatus");
  const submitButton = contactForm.querySelector('button[type="submit"]');
  let initializedPublicKey = "";

  const setFormStatus = (message, state) => {
    if (!formStatus) {
      return;
    }
    formStatus.textContent = message;
    if (state) {
      formStatus.dataset.state = state;
    } else {
      delete formStatus.dataset.state;
    }
  };

  contactForm.addEventListener("submit", async (event) => {
    event.preventDefault();
    if (contactForm.dataset.sending === "true") {
      return;
    }

    const nameField = contactForm.elements.namedItem("name");
    const emailField = contactForm.elements.namedItem("email");
    const messageField = contactForm.elements.namedItem("message");
    const honeypot = contactForm.elements.namedItem("website");

    nameField.value = nameField.value.trim();
    emailField.value = emailField.value.trim();
    messageField.value = messageField.value.trim();

    if (!contactForm.reportValidity()) {
      return;
    }

    if (honeypot.value.trim()) {
      setFormStatus("Không thể xử lý yêu cầu. Vui lòng thử lại.", "error");
      return;
    }

    const config = window.PORTFOLIO_EMAIL_CONFIG;
    if (!config || !config.publicKey || !config.serviceId || !config.templateId) {
      setFormStatus("Form chưa được cấu hình. Vui lòng liên hệ qua email bên cạnh.", "error");
      return;
    }

    if (!window.emailjs) {
      setFormStatus("Dịch vụ gửi email chưa tải được. Vui lòng thử lại sau.", "error");
      return;
    }

    contactForm.dataset.sending = "true";
    contactForm.setAttribute("aria-busy", "true");
    if (submitButton) {
      submitButton.disabled = true;
      submitButton.dataset.originalText = submitButton.textContent;
      submitButton.textContent = "Đang gửi...";
    }
    setFormStatus("Đang gửi thông tin...", "pending");

    try {
      if (initializedPublicKey !== config.publicKey) {
        window.emailjs.init({ publicKey: config.publicKey });
        initializedPublicKey = config.publicKey;
      }

      await window.emailjs.sendForm(config.serviceId, config.templateId, contactForm);
      contactForm.reset();
      setFormStatus("Gửi thành công. Cảm ơn bạn đã liên hệ!", "success");
    } catch (error) {
      console.error("EmailJS send failed.", error);
      setFormStatus("Gửi chưa thành công. Vui lòng thử lại hoặc liên hệ qua email.", "error");
    } finally {
      delete contactForm.dataset.sending;
      contactForm.removeAttribute("aria-busy");
      if (submitButton) {
        submitButton.disabled = false;
        submitButton.textContent = submitButton.dataset.originalText || "Gửi email";
        delete submitButton.dataset.originalText;
      }
    }
  });
}
