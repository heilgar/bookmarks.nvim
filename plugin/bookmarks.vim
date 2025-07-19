if exists('g:loaded_bookmarks') | finish | endif
let g:loaded_bookmarks = 1

command! BookmarkAdd lua require('bookmarks.commands').add_bookmark()
command! BookmarkRemove lua require('bookmarks.commands').remove_bookmark()
command! BookmarksToggleBranchScope lua require('bookmarks').toggle_branch_scope()
command! Bookmarks Telescope bookmarks
command! -nargs=1 BookmarkListCreate lua require('bookmarks.commands').create_list(<f-args>)
command! -nargs=1 BookmarkListSwitch lua require('bookmarks.commands').switch_list(<f-args>)
command! -nargs=+ BookmarkListRename lua require('bookmarks.commands').rename_list(<f-args>)
command! -nargs=1 BookmarkListDelete lua require('bookmarks.commands').delete_list(<f-args>)
command! BookmarkListShow lua require('bookmarks.commands').show_lists()
command! BookmarkStatus lua require('bookmarks.commands').show_status()
command! BookmarkStatusTelescope Telescope bookmarks status

lua require('bookmarks')

