After many attemps to integrate tangling into neovim:

* [ntangle.nvim](https://github.com/jbyuki/ntangle.nvim)
* [ntangle.vim](https://github.com/jbyuki/ntangle.vim)
* [ntangle-ts.vim](https://github.com/jbyuki/ntangle-ts.nvim)
* [ntangle-lsp.nvim](https://github.com/jbyuki/ntangle-lsp.nvim)
* [tree-sitter-ntangle](https://github.com/jbyuki/tree-sitter-ntangle)
* [ntangle-notebook.nvim](https://github.com/jbyuki/ntangle-notebook.nvim)

The main problems with plugins are proper syntax highlighting and LSP. 
This works more or less with ntangle-ts.nvim. But LSP is a major obstacle. 
While it's still possible to implement using plugins, it's a one more step 
in complexity compared to syntax highlighting, which I'm don't have the motivation
to do.

Instead, the solution to modify Neovim goes as follows. The user modify
the buffer which is tangled. In the background, an untangled buffer will be
also be synchronized. This will allow to run tree-sitter, LSP, etc... on 
this hidden buffer, and reflect back the changes in the tangled buffer.
This means just implementing the tangling process once, and in theory,
with very big ifs, it should work for anything.

Will it work, will not work, that is the question.
