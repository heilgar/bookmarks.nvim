if exists('g:loaded_bookmarks') | finish | endif
let g:loaded_bookmarks = 1

command! BookmarkAdd lua require('bookmarks.commands').add_bookmark()
command! BookmarkRemove lua require('bookmarks.commands').remove_bookmark()
command! BookmarksToggleBranchScope lua require('bookmarks').toggle_branch_scope()
command! Bookmarks Telescope bookmarks

lua require('bookmarks')

