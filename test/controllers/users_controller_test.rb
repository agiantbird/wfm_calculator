require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get new_user_url
    assert_response :success
  end

  test "should create user with valid attributes" do
    assert_difference("User.count", 1) do
      post users_url, params: { user: { name: "Jane Doe" } }
    end

    assert_redirected_to root_path
    follow_redirect!
    assert_select "div.notice", "Jane Doe was successfully created"
  end

  test "should not create user without name" do
    assert_no_difference("User.count") do
      post users_url, params: { user: { name: "" } }
    end

    assert_response :unprocessable_entity
  end

  test "should display error messages when user creation fails" do
    post users_url, params: { user: { name: "" } }

    assert_response :unprocessable_entity
    assert_select "div[style*='color: red']"
    assert_select "li", /Name can't be blank/i
  end

  test "should have create user link on home page" do
    get root_url
    assert_select "a[href=?]", new_user_path, text: "Create New User"
  end

  test "should render new user form with proper fields" do
    get new_user_url
    assert_select "form[action=?]", users_path do
      assert_select "input[name=?]", "user[name]"
      assert_select "input[type=submit][value=?]", "Create User"
      assert_select "a[href=?]", root_path, text: "Cancel"
    end
  end
end
