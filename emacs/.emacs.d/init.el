(require 'package)
(require 'cl-lib)

;; Use the system CA bundle so TLS works behind ZScaler.
(let ((ca (or (getenv "REQUESTS_CA_BUNDLE")
              "/etc/ssl/certs/ca-certificates.crt")))
  (when (file-readable-p ca)
    (setq gnutls-trustfiles (list ca))))

;; Proxy: wire in before package-initialize so archive fetches go through it.
;; Reads HTTP_PROXY / http_proxy from the environment (set by install.sh --proxy).
(let ((proxy (or (getenv "HTTP_PROXY") (getenv "http_proxy"))))
  (when (and proxy (not (string-empty-p proxy)))
    (setq url-proxy-services
          `(("http"    . ,(replace-regexp-in-string "^https?://" "" proxy))
            ("https"   . ,(replace-regexp-in-string "^https?://" "" proxy))
            ("no_proxy" . "localhost,127.0.0.1")))))

(setq package-archives '(("gnu"   . "https://elpa.gnu.org/packages/")
                         ("melpa" . "https://melpa.org/packages/")))
(package-initialize)

;; Only refresh and install if a package is genuinely missing — avoids
;; hitting the network on every Emacs startup for already-installed packages.
(let ((missing (cl-remove-if #'package-installed-p '(rust-mode yaml-mode))))
  (when missing
    (package-refresh-contents)
    (dolist (pkg missing)
      (package-install pkg))))

;; Redirect Emacs customization to a separate file so Custom never writes
;; into .emacs or init.el.
(setq custom-file (expand-file-name "~/.emacs.d/custom.el"))
(when (file-exists-p custom-file)
  (load custom-file))
