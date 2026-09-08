(require 'package)
(setq package-archives '(("gnu"   . "https://elpa.gnu.org/packages/")
                         ("melpa" . "https://melpa.org/packages/")))
(package-initialize)

(unless (package-installed-p 'rust-mode)
  (package-refresh-contents)
  (package-install 'rust-mode))

(global-font-lock-mode 1)
(line-number-mode 1)
(column-number-mode 1)
(setq-default indent-tabs-mode nil)
(setq default-tab-width 4
      tab-width 4)
(setq-default show-trailing-whitespace t)
(setq-default auto-fill-function 'do-auto-fill)

(require 'rust-mode)
(add-to-list 'auto-mode-alist '("\\.hip\\'" . c++-mode))
