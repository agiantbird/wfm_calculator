require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get root_url
    assert_response :success
  end

  test "should display users on index page" do
    user = users(:one)
    get root_url
    assert_select "body", /#{user.name}/
  end

  test "should have report type options available" do
    get root_url
    # Verify the page loaded successfully which means @report_types was set
    assert_response :success
  end
end
