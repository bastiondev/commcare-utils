class UserConstraint
  def matches?(request)
    passwordless_session_id = request.session['passwordless_session_id--user']
    return false unless passwordless_session_id
    Passwordless::Session.find(passwordless_session_id).authenticatable
  end
end