;;; init.el --- Initialization file for Emacs

;;; Commentary:
;; Emacs Startup File

(require 'package)
;;; Code:

(add-to-list
 'package-archives
 '("melpa" . "http://melpa.org/packages/"))

(unless package--initialized (package-initialize))

;; inform byte compiler about free variables
(eval-when-compile
  (defvar desktop-save)
  (defvar desktop-path)
  (defvar desktop-load-locked-desktop)
  (defvar desktop-auto-save-timeout))

;; desktop-save settings
(desktop-save-mode 1)
(setq desktop-save t
      desktop-path '("~/.emacs.d/")
      desktop-load-locked-desktop t
      desktop-auto-save-timeout 5)

;; miscellaneous settings
(add-to-list 'default-frame-alist '(fullscreen . maximized))
(add-hook 'before-save-hook 'delete-trailing-whitespace)
(global-auto-revert-mode t)
(setq column-number-mode t)
(setq-default indent-tabs-mode nil)

;; automatic package installation
(unless (package-installed-p 'use-package)
  (package-refresh-contents)
  (package-install 'use-package))

;; auto updates
(use-package auto-package-update
  :ensure t
  :config
  (setq auto-package-update-delete-old-versions t
        auto-package-update-interval 4)
  (auto-package-update-maybe))

;; external package configurations

(use-package exec-path-from-shell
  :ensure t
  :config
  (when (or (daemonp) (memq window-system '(mac ns x)))
    (exec-path-from-shell-initialize)))

(use-package helm
  :ensure t
  :defines (helm-find-files-map helm-read-file-map)
  :bind (("M-x" . helm-M-x)
         ("C-x C-f" . helm-find-files)
         ("C-x b" . helm-mini)
         :map helm-map
         ("<tab>" . helm-execute-persistent-action)
         ("C-z" . helm-select-action)
         :map helm-find-files-map
         ("<DEL>" . helm-ff-delete-char-backward)
         ("C-<backspace>" . helm-find-files-up-one-level)
         :map helm-read-file-map
         ("<DEL>" . helm-ff-delete-char-backward)
         ("C-<backspace>" . helm-find-files-up-one-level))
  :init (helm-mode 1))

(use-package magit
  :ensure t
  :bind (("C-x g" . magit-status)))

(use-package elpy
  :ensure t
  :bind (:map elpy-mode-map
              ("C-<up>" . nil)
              ("C-<down>" . nil))
  :hook
  (elpy-mode . (lambda ()
                 (add-hook 'before-save-hook
                           'elpy-format-code nil
                           'local)))
  :init (elpy-enable)
  :config (setq elpy-modules
                (delq 'elpy-module-flymake
                      elpy-modules)))

(use-package flycheck
  :ensure t
  :hook
  (flycheck-mode . (lambda()
                     ;; Use ESLint from local node_modules
                     (let* ((current (or buffer-file-name
                                         default-directory))
                            (nmodules (locate-dominating-file
                                       current
                                       "node_modules"))
                            (eslint (and nmodules
                                         (expand-file-name
                                          "node_modules/.bin/eslint"
                                          nmodules))))
                       (when (and eslint (file-executable-p eslint))
                         (setq-local flycheck-javascript-eslint-executable
                                     eslint)))))
  :config
  (global-flycheck-mode))

(use-package company
  :ensure t
  :init (global-company-mode))

(defun setup-tide-mode ()
  "Set up tide mode and turn on related modes with tide specific configurations."
  (tide-setup)
  (tide-hl-identifier-mode 1)
  (flycheck-mode 1)
  (setq flycheck-check-syntax-automatically
        '(save mode-enabled idle-change))
  (company-mode 1)
  (eldoc-mode 1))

(use-package tide
  :ensure t
  :after (typescript-mode flycheck company)
  :bind (:map tide-mode-map
              ("C-x t s" . tide-restart-server)
              ("C-x t d" . tide-documentation-at-point)
              ("C-x t l" . tide-references)
              ("C-x t p" . tide-project-errors)
              ("C-x t e" . tide-error-at-point)
              ("C-x t n" . tide-rename-symbol)
              ("C-x t f" . tide-rename-file)
              ("C-x t o" . tide-format)
              ("C-x t x" . tide-fix)
              ("C-x t r" . tide-refactor)
              ("C-x t i" . tide-organize-imports)
              ("C-x t j" . tide-jsdoc-template)
              ("C-x t a" . tide-list-servers))
  :hook
  ((typescript-mode . setup-tide-mode)
   (before-save . tide-format-before-save))
  :functions flycheck-add-next-checker
  :config
  (flycheck-add-next-checker 'javascript-tide 'javascript-eslint)
  (flycheck-add-next-checker 'typescript-tide 'javascript-eslint)
  (flycheck-add-next-checker 'jsx-tide 'javascript-eslint)
  (flycheck-add-next-checker 'tsx-tide 'javascript-eslint))

(use-package web-mode
  :ensure t
  :after (tide flycheck)
  :mode ("\\.jsx\\'" "\\.tsx\\'")
  :functions flycheck-add-mode
  :hook
  (web-mode . (lambda ()
                ;; Set up tide only if file extension is jsx or tsx
                (let ((ext (file-name-extension buffer-file-name)))
                  (when (or
                         (string-equal "jsx" ext)
                         (string-equal "tsx" ext))
                    (setup-tide-mode)))))
  :config
  (flycheck-add-mode 'jsx-tide 'web-mode)
  (flycheck-add-mode 'tsx-tide 'web-mode))

(use-package js2-mode
  :ensure t
  :after (tide flycheck)
  :mode "\\.js\\'"
  :functions flycheck-add-mode
  :hook
  (js2-mode . setup-tide-mode)
  :config
  (flycheck-add-mode 'javascript-tide 'js2-mode))

(require 'term)
(use-package multi-term
  :ensure t
  :bind (("C-x M-m" . multi-term)
         ("C-x M-o" . multi-term-dedicated-open)
         ("C-x M-t" . multi-term-dedicated-toggle)
         ("C-x M-s" . multi-term-dedicated-select)
         ("C-x M-c" . multi-term-dedicated-close))
  :config
  ;; Change default multi-term shell to zsh if available
  (let ((zsh-bin (executable-find "zsh")))
    (when zsh-bin
      (setq multi-term-program zsh-bin)))
  (defun term-send-C-x ()
    (interactive)
    (term-send-raw-string "\C-x"))
  (setq term-bind-key-alist
        (append term-bind-key-alist
                '(("C-c C-j" . term-line-mode)
                  ("C-c C-k" . term-char-mode)
                  ("C-c C-x" . term-send-C-x)
                  ("C-<" . multi-term-prev)
                  ("C->" . multi-term-next)))))

(use-package json-mode
  :ensure t)

(use-package yaml-mode
  :ensure t)

(use-package dockerfile-mode
  :ensure t)

(use-package docker-compose-mode
  :ensure t)

(use-package which-key
  :ensure t
  :init (which-key-mode 1))

(use-package crux
  :ensure t
  :bind (("C-c t" . crux-transpose-windows)
         ("C-c d" . crux-delete-file-and-buffer)
         ("C-c r" . crux-rename-file-and-buffer)
         ("C-c o" . crux-kill-other-buffers)
         ("C-c i" . crux-find-user-init-file)
         ("C-c k" . crux-kill-whole-line)
         ("C-c DEL" . crux-kill-line-backwards)
         ("C-c e" . crux-sudo-edit)))

(use-package minimap
  :ensure t
  :bind (("C-c m" . minimap-mode))
  :init
  (setq minimap-window-location 'right)
  (minimap-mode 1))

(use-package smartparens
  :ensure t
  :init
  (require 'smartparens-config)
  :bind (:map smartparens-mode-map
              ("M-p <right>" . sp-forward-sexp)
              ("M-p <left>" . sp-backward-sexp)
              ("M-p <down>" . sp-down-sexp)
              ("M-p <up>" . sp-backward-up-sexp)
              ("M-p s" . sp-splice-sexp)
              ("M-p x" . sp-kill-sexp))
  :config
  (smartparens-global-mode t))

(use-package hideshow
  :bind (:map hs-minor-mode-map
              ("C-c +" . hs-show-block)
              ("C-c -" . hs-hide-block)
              ("C-c *" . hs-show-all)
              ("C-c /" . hs-hide-all))
  :hook ((emacs-lisp-mode typescript-mode python-mode) . hs-minor-mode))

(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(custom-enabled-themes '(tango-dark))
 '(elpy-rpc-python-command "python3")
 '(package-selected-packages '(flycheck elpy magit helm auto-package-update use-package))
 '(python-shell-interpreter "python3"))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )

(provide 'init)
;;; init.el ends here
