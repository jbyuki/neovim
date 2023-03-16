vim.api.nvim_buf_attach(1, false, {
  on_extmark = function(str, buf)
    print("hello")
  end
})
