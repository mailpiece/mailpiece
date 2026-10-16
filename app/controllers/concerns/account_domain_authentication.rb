# Nobody signs in on a newsletter's own domain: what would ask for it is not found there, and a session is
# neither written nor resumed from a cookie the browser still holds, so the domain sets no cookie and its
# visitor is always a reader. Included after Authentication, whose methods these override.
module AccountDomainAuthentication
  private

  def resume_session
    super unless AccountDomain.request?(request)
  end

  def request_authentication
    if AccountDomain.request?(request)
      head :not_found
    else
      super
    end
  end
end
