module InvitationsHelper
  def invitation_role_options
    membership = Current.company.memberships.find_by(user: Current.user)
    options = [ [ "Member", "member" ] ]
    options.unshift([ "Admin", "admin" ]) if membership&.owner?
    options
  end
end
