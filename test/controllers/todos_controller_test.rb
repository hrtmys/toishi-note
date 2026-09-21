require "test_helper"

class TodosControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "redirects to the Todos mode of the main pane" do
    get todos_url
    assert_redirected_to root_path(todos: true)
  end
end
