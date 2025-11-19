require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "should not save user without name" do
    user = User.new(email: "test@example.com")
    assert_not user.save, "Saved the user without a name"
  end

  test "should save user with valid attributes" do
    user = User.new(name: "John Doe", email: "john@example.com")
    assert user.save, "Failed to save a valid user"
  end

  test "should have many reports" do
    user = User.reflect_on_association(:reports)
    assert_equal :has_many, user.macro
  end

  test "should destroy associated reports when user is destroyed" do
    user = User.create!(name: "Test User")
    report = user.reports.create!(report_type: "fte", name: "Test Report")
    report_id = report.id

    assert_difference "Report.count", -1 do
      user.destroy
    end

    assert_nil Report.find_by(id: report_id)
  end
end
