;; init.el is skipped when ~/.emacs exists; load it explicitly so the
;; package bootstrap and proxy setup always run first.
(load (expand-file-name "~/.emacs.d/init.el"))

;; Silently follow symlinks into version-controlled source (stow links).
(setq vc-follow-symlinks t)

(global-font-lock-mode 1)
(line-number-mode 1)
(column-number-mode 1)

(setq-default indent-tabs-mode nil)
(setq default-tab-width 4
      tab-width 4)

(setq-default show-trailing-whitespace t)

;; Auto-fill only in prose modes, not in code.
(dolist (hook '(text-mode-hook
                org-mode-hook
                markdown-mode-hook))
  (add-hook hook 'auto-fill-mode))

(require 'rust-mode)
(require 'yaml-mode)

;; .hip files follow C++ syntax (HIP is CUDA-compatible)
(add-to-list 'auto-mode-alist '("\\.hip\\'" . c++-mode))
