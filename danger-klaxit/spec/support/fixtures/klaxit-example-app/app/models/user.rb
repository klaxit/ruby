class User < ActiveRecord::Base
  def dangerous(user_input_column)
    User.connection.select_values("SELECT #{user_input_column} FROM users")
  end
end
