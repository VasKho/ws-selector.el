;;; ws-selector --- Simple workspace management per buffers.
;;;
;;; Author: vaslch0 <vasya.khoroshavin@gmail.com>
;;; URL: https://github.com/VasKho/ws-selector.el
;;; Package-Requires: (cl-lib)
;;; Commentary:
;;; Provides variable which stores current forkspace
;;; for every opened buffer.
;;; Code:

(require 'cl-lib)

(defgroup ws-selector nil
  "Manage workspaces config."
  :prefix "ws-selector-"
  :group 'convenience)

(defcustom ws-selector-selection-alist `(("Home" . "~/"))
  "This variable must contain cons which are (<name> . <workspace-directory>)."
  :type 'variable
  :group 'ws-selector)

(defcustom ws-selector-workdir-indent 2
  "This variable is used to configure indent in completion view."
  :type 'variable
  :group 'ws-selector)

(defvar ws-selector-workspace-list '()
  "Don't edit this variable manually.")

(defun ws-selector--preprocess-selection-alist ()
  "This function is used to format selection alist.
Now it adds more whitespaces before directory of workspace to make its look
in vertico completion more nice.  This function must be called after
initializing."
  (let ((longest-prefix-len (+ ws-selector-workdir-indent
			       (apply #'max (mapcar (lambda (a) (length (car a))) ws-selector-selection-alist)))))
    (setq ws-selector-selection-alist
	  (mapcar
	   (lambda (a)
	     (cons (car a) (concat (make-string (- longest-prefix-len (length (car a))) ? ) (cdr a))))
		  ws-selector-selection-alist))))

;;;###autoload
(defun ws-selector-set-frame-working-directory (frame path)
  "This function is used to set PATH as working directory for FRAME."
  (cl-loop for cons in ws-selector-workspace-list
	   when (equal (car cons) frame) do
	   (setq ws-selector-workspace-list (remove cons ws-selector-workspace-list))
	   return nil)
  (push (cons frame path) ws-selector-workspace-list)
  (when (fboundp 'dired-change-workdir-hook)
    (apply #'dired-change-workdir-hook `(,path))))

(defun ws-selector--set-frame-workspace (frame &optional workspace-name)
  "This function is used to set workspace with name WORKSPACE-NAME for FRAME."
  (unless workspace-name (setq workspace-name "Home"))
  (cl-loop for cons in ws-selector-workspace-list
	   when (eq (car cons) frame) do
	   (setq ws-selector-workspace-list (remove cons ws-selector-workspace-list))
	   return nil)
  (ws-selector-set-frame-working-directory
   frame
   (cl-loop for ws in ws-selector-selection-alist
	    when (equal (car ws) workspace-name)
	    return (cdr ws))))

(defun ws-selector--remove-deleted-frames-from-list (frame)
  "This function delete all dead frames from `ws-selector-workspace-list'.
FRAME is here for `after-delete-frame-functions' compatibility."
  (interactive)
  (cl-loop for frame-cons in ws-selector-workspace-list
	   when (equal frame (car frame-cons)) do
	   (setq ws-selector-workspace-list (remove frame-cons ws-selector-workspace-list))
	   return nil))

(defun ws-selector--annotation-function (candidate)
  "Annotation function for completion.
It returns description (i.e. working directory) for CANDIDATE
according to `ws-selector-selection-alist'."
  (cdr (assoc candidate ws-selector-selection-alist)))

;;;###autoload
(defun ws-selector-get-working-directory (&optional frame)
  "Get working directory for FRAME.
FRAME defaults to `selected-frame'"
  (interactive)
  (unless frame (setq frame (selected-frame)))
  (cl-loop for cons in ws-selector-workspace-list
	   when (eq (car cons) frame)
	   return (string-trim-left (cdr cons))))

;;;###autoload
(defun ws-selector-select-workspace ()
  "This function is used to select workspace for `selected-frame'."
  (interactive)
  (let* ((completion-extra-properties '(:annotation-function ws-selector--annotation-function))
	 (selected-ws-name (completing-read "Select workspace: " ws-selector-selection-alist)))
    (ws-selector--set-frame-workspace (selected-frame) selected-ws-name)))

(setq after-delete-frame-functions
      (append after-delete-frame-functions
	      '(ws-selector--remove-deleted-frames-from-list)))

(ws-selector--preprocess-selection-alist)

(provide 'ws-selector)
;;; ws-selector.el ends here
