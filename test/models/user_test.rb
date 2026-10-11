require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "anyone with an email address can sign in" do
    assert_equal "ada@example.com", User.for_sign_in("  Ada@Example.com ").email_address
    assert_equal User.for_sign_in("ada@example.com"), User.for_sign_in("ADA@example.com")
    assert_nil User.for_sign_in("not an email")
  end

  test "a code signs in once" do
    user = User.for_sign_in("ada@example.com")
    code = user.issue_sign_in_code

    assert_match(/\A\d{6}\z/, code)
    assert user.redeem_sign_in_code(code)
    assert_not user.redeem_sign_in_code(code)
  end

  test "a new code voids the last one" do
    user = User.for_sign_in("ada@example.com")
    old = user.issue_sign_in_code
    user.issue_sign_in_code

    assert_not user.redeem_sign_in_code(old)
  end

  test "a code just sent is remembered for a moment" do
    user = User.for_sign_in("ada@example.com")
    assert_not user.sign_in_code_just_sent?

    user.issue_sign_in_code
    assert user.sign_in_code_just_sent?

    travel 31.seconds do
      assert_not user.sign_in_code_just_sent?
    end
  end

  test "codes last three hours" do
    user = User.for_sign_in("ada@example.com")
    code = user.issue_sign_in_code

    travel SignInCode::LIFETIME + 1.minute do
      assert_not user.redeem_sign_in_code(code)
    end
  end

  test "a few wrong guesses use the code up" do
    user = User.for_sign_in("ada@example.com")
    code = user.issue_sign_in_code
    wrong = code == "000000" ? "111111" : "000000"

    SignInCode::MAX_ATTEMPTS.times { assert_not user.redeem_sign_in_code(wrong) }
    assert_not user.redeem_sign_in_code(code)
  end
end
