# Rails has no built-in :md format; registering it lets /todos.md resolve
# to TodosController#index's format.md branch via ordinary routing.
Mime::Type.register "text/markdown", :md
