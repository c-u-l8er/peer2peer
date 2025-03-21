// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html";
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import topbar from "../vendor/topbar";

let csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
  hooks: Hooks,
});

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" });
window.addEventListener("phx:page-loading-start", (_info) => topbar.show(300));
window.addEventListener("phx:page-loading-stop", (_info) => topbar.hide());

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;

// Mobile menu toggle
document.addEventListener("DOMContentLoaded", () => {
  const mobileMenuButton = document.querySelector(".mobile-menu-button");
  const mobileMenu = document.getElementById("mobile-menu");

  if (mobileMenuButton && mobileMenu) {
    mobileMenuButton.addEventListener("click", () => {
      mobileMenu.classList.toggle("hidden");
    });
  }
});

// Chat scrolling functionality
document.addEventListener("DOMContentLoaded", () => {
  const messagesContainer = document.getElementById("messages-container");

  if (messagesContainer) {
    const scrollToBottom = () => {
      messagesContainer.scrollTop = messagesContainer.scrollHeight;
    };

    // Scroll to bottom on initial load
    scrollToBottom();

    // Create a mutation observer to watch for new messages
    const observer = new MutationObserver((mutations) => {
      for (const mutation of mutations) {
        if (mutation.addedNodes.length) {
          scrollToBottom();
        }
      }
    });

    // Start observing the messages container
    observer.observe(messagesContainer, { childList: true });
  }
});

const Hooks = {
  MessageInput: {
    mounted() {
      // Auto-resize the textarea as the user types
      const textarea = this.el;

      // Function to adjust the height
      const adjustHeight = () => {
        textarea.style.height = "auto";
        textarea.style.height = `${textarea.scrollHeight}px`;
      };

      // Adjust on input
      textarea.addEventListener("input", adjustHeight);

      // Handle form submission on Enter key (without Shift)
      textarea.addEventListener("keydown", (e) => {
        if (e.key === "Enter" && !e.shiftKey) {
          e.preventDefault();
          this.pushEvent("handle_keydown", {
            key: "Enter",
            value: textarea.value,
          });
        }
      });

      // Watch for reset flag changes
      this.handleEvent("reset_input", () => {
        textarea.value = "";
        adjustHeight();
      });
    },

    updated() {
      // Check if we need to reset the input
      if (this.el.dataset.reset === "true") {
        this.el.value = "";
        this.el.style.height = "auto";
      }
    },
  },

  MessageContainer: {
    mounted() {
      this.scrollToBottom();

      // Create observer to watch for new messages
      this.observer = new MutationObserver(() => {
        this.scrollToBottom();
      });

      // Start observing
      this.observer.observe(this.el, {
        childList: true,
        subtree: true,
      });
    },

    updated() {
      this.scrollToBottom();
    },

    destroyed() {
      if (this.observer) {
        this.observer.disconnect();
      }
    },

    scrollToBottom() {
      this.el.scrollTop = this.el.scrollHeight;
    },
  },
};
