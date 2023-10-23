defmodule Animelodica.AccountsTest do
  use Animelodica.DataCase

  alias Animelodica.Accounts

  import Animelodica.AccountsFixtures
  alias Animelodica.Accounts.{User, UserToken}

  describe "get_user_by_identifier/1" do
    test "does not return the user if the identifier does not exist" do
      refute Accounts.get_user_by_identifier("unknown@example.com")
    end

    test "returns the user if the identifier exists" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = Accounts.get_user_by_identifier(user.identifier)
    end
  end

  describe "get_user_by_identifier_and_password/2" do
    test "does not return the user if the identifier does not exist" do
      refute Accounts.get_user_by_identifier_and_password("unknown@example.com", "hello world!")
    end

    test "does not return the user if the password is not valid" do
      user = user_fixture()
      refute Accounts.get_user_by_identifier_and_password(user.identifier, "invalid")
    end

    test "returns the user if the identifier and password are valid" do
      %{id: id} = user = user_fixture()

      assert %User{id: ^id} =
               Accounts.get_user_by_identifier_and_password(
                 user.identifier,
                 valid_user_password()
               )
    end
  end

  describe "get_user!/1" do
    test "raises if id is invalid" do
      assert_raise Ecto.NoResultsError, fn ->
        Accounts.get_user!(-1)
      end
    end

    test "returns the user with the given id" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = Accounts.get_user!(user.id)
    end
  end

  describe "register_user/1" do
    test "requires identifier and password to be set" do
      {:error, changeset} = Accounts.register_user(%{})

      assert %{
               password: ["can't be blank"],
               identifier: ["can't be blank"]
             } = errors_on(changeset)
    end

    test "validates identifier and password when given" do
      {:error, changeset} =
        Accounts.register_user(%{identifier: "not valid", password: "not valid"})

      assert %{
               identifier: ["must have no spaces"],
               password: ["should be at least 12 character(s)"]
             } = errors_on(changeset)
    end

    test "validates maximum values for identifier and password for security" do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Accounts.register_user(%{identifier: too_long, password: too_long})
      assert "should be at most 160 character(s)" in errors_on(changeset).identifier
      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "validates identifier uniqueness" do
      %{identifier: identifier} = user_fixture()
      {:error, changeset} = Accounts.register_user(%{identifier: identifier})
      assert "has already been taken" in errors_on(changeset).identifier

      # Now try with the upper cased identifier too, to check that identifier case is ignored.
      {:error, changeset} = Accounts.register_user(%{identifier: String.upcase(identifier)})
      assert "has already been taken" in errors_on(changeset).identifier
    end

    test "registers users with a hashed password" do
      identifier = unique_user_identifier()
      {:ok, user} = Accounts.register_user(valid_user_attributes(identifier: identifier))
      assert user.identifier == identifier
      assert is_binary(user.hashed_password)
      assert is_nil(user.confirmed_at)
      assert is_nil(user.password)
    end
  end

  describe "change_user_registration/2" do
    test "returns a changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_user_registration(%User{})
      assert changeset.required == [:password, :identifier]
    end

    test "allows fields to be set" do
      identifier = unique_user_identifier()
      password = valid_user_password()

      changeset =
        Accounts.change_user_registration(
          %User{},
          valid_user_attributes(identifier: identifier, password: password)
        )

      assert changeset.valid?
      assert get_change(changeset, :identifier) == identifier
      assert get_change(changeset, :password) == password
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "change_user_identifier/2" do
    test "returns a user changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_user_identifier(%User{})
      assert changeset.required == [:identifier]
    end
  end

  describe "apply_user_identifier/3" do
    setup do
      %{user: user_fixture()}
    end

    test "requires identifier to change", %{user: user} do
      {:error, changeset} = Accounts.apply_user_identifier(user, valid_user_password(), %{})
      assert %{identifier: ["did not change"]} = errors_on(changeset)
    end

    test "validates identifier", %{user: user} do
      {:error, changeset} =
        Accounts.apply_user_identifier(user, valid_user_password(), %{identifier: "not valid"})

      assert %{identifier: ["must have no spaces"]} = errors_on(changeset)
    end

    test "validates maximum value for identifier for security", %{user: user} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Accounts.apply_user_identifier(user, valid_user_password(), %{identifier: too_long})

      assert "should be at most 160 character(s)" in errors_on(changeset).identifier
    end

    test "validates identifier uniqueness", %{user: user} do
      %{identifier: identifier} = user_fixture()
      password = valid_user_password()

      {:error, changeset} =
        Accounts.apply_user_identifier(user, password, %{identifier: identifier})

      assert "has already been taken" in errors_on(changeset).identifier
    end

    test "validates current password", %{user: user} do
      {:error, changeset} =
        Accounts.apply_user_identifier(user, "invalid", %{identifier: unique_user_identifier()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "applies the identifier without persisting it", %{user: user} do
      identifier = unique_user_identifier()

      {:ok, user} =
        Accounts.apply_user_identifier(user, valid_user_password(), %{identifier: identifier})

      assert user.identifier == identifier
      assert Accounts.get_user!(user.id).identifier != identifier
    end
  end

  # describe "update_user_identifier/2" do
  #   # TODO
  #   setup do
  #     user = user_fixture()
  #     identifier = unique_user_identifier()

  #     %{user: user, identifier: identifier}
  #   end

  #   test "updates the email with a valid token", %{user: user, token: token, email: email} do
  #     assert Accounts.update_user_email(user, token) == :ok
  #     changed_user = Repo.get!(User, user.id)
  #     assert changed_user.email != user.email
  #     assert changed_user.email == email
  #     assert changed_user.confirmed_at
  #     assert changed_user.confirmed_at != user.confirmed_at
  #     refute Repo.get_by(UserToken, user_id: user.id)
  #   end

  #   test "does not update email with invalid token", %{user: user} do
  #     assert Accounts.update_user_email(user, "oops") == :error
  #     assert Repo.get!(User, user.id).email == user.email
  #     assert Repo.get_by(UserToken, user_id: user.id)
  #   end

  #   test "does not update email if user email changed", %{user: user, token: token} do
  #     assert Accounts.update_user_email(%{user | email: "current@example.com"}, token) == :error
  #     assert Repo.get!(User, user.id).email == user.email
  #     assert Repo.get_by(UserToken, user_id: user.id)
  #   end

  #   test "does not update email if token expired", %{user: user, token: token} do
  #     {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
  #     assert Accounts.update_user_email(user, token) == :error
  #     assert Repo.get!(User, user.id).email == user.email
  #     assert Repo.get_by(UserToken, user_id: user.id)
  #   end
  # end

  describe "change_user_password/2" do
    test "returns a user changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_user_password(%User{})
      assert changeset.required == [:password]
    end

    test "allows fields to be set" do
      changeset =
        Accounts.change_user_password(%User{}, %{
          "password" => "new valid password"
        })

      assert changeset.valid?
      assert get_change(changeset, :password) == "new valid password"
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "update_user_password/3" do
    setup do
      %{user: user_fixture()}
    end

    test "validates password", %{user: user} do
      {:error, changeset} =
        Accounts.update_user_password(user, valid_user_password(), %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{user: user} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Accounts.update_user_password(user, valid_user_password(), %{password: too_long})

      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "validates current password", %{user: user} do
      {:error, changeset} =
        Accounts.update_user_password(user, "invalid", %{password: valid_user_password()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "updates the password", %{user: user} do
      {:ok, user} =
        Accounts.update_user_password(user, valid_user_password(), %{
          password: "new valid password"
        })

      assert is_nil(user.password)
      assert Accounts.get_user_by_identifier_and_password(user.identifier, "new valid password")
    end

    test "deletes all tokens for the given user", %{user: user} do
      _ = Accounts.generate_user_session_token(user)

      {:ok, _} =
        Accounts.update_user_password(user, valid_user_password(), %{
          password: "new valid password"
        })

      refute Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "generate_user_session_token/1" do
    setup do
      %{user: user_fixture()}
    end

    test "generates a token", %{user: user} do
      token = Accounts.generate_user_session_token(user)
      assert user_token = Repo.get_by(UserToken, token: token)
      assert user_token.context == "session"

      # Creating the same token for another user should fail
      assert_raise Ecto.ConstraintError, fn ->
        Repo.insert!(%UserToken{
          token: user_token.token,
          user_id: user_fixture().id,
          context: "session"
        })
      end
    end
  end

  describe "get_user_by_session_token/1" do
    setup do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      %{user: user, token: token}
    end

    test "returns user by token", %{user: user, token: token} do
      assert session_user = Accounts.get_user_by_session_token(token)
      assert session_user.id == user.id
    end

    test "does not return user for invalid token" do
      refute Accounts.get_user_by_session_token("oops")
    end

    test "does not return user for expired token", %{token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Accounts.get_user_by_session_token(token)
    end
  end

  describe "delete_user_session_token/1" do
    test "deletes the token" do
      user = user_fixture()
      token = Accounts.generate_user_session_token(user)
      assert Accounts.delete_user_session_token(token) == :ok
      refute Accounts.get_user_by_session_token(token)
    end
  end

  describe "inspect/2 for the User module" do
    test "does not include password" do
      refute inspect(%User{password: "123456"}) =~ "password: \"123456\""
    end
  end
end
