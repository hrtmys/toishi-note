# /todos now redirects into the Todos mode of the main pane
# (HomeController#index) — kept only so old links/bookmarks still resolve.
class TodosController < ApplicationController
  def index
    redirect_to root_path(todos: true)
  end
end
