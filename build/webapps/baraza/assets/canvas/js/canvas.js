$(".summernote").summernote({
    toolbar: [
        // [groupName, [list of button]]
        ['style', ['bold', 'italic', 'underline', 'clear']],
        ['font', ['strikethrough', 'superscript', 'subscript']],
        ['color', ['color']],
        ['para', ['ul', 'ol', 'paragraph']],
        ['height', ['height']]
    ],
    height: 100,
    minHeight: null,
    maxHeight: null,
    focus: !0,
    codemirror: { // codemirror options
        theme: 'monokai'
    }
});