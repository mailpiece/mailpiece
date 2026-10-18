module DnsTestHelper
  PUBLIC_IP = "93.184.216.34"

  private

  # Surfguard resolves through Resolv.getaddresses and reports a resolver error as Unresolvable.
  def stub_dns_resolution(*ips)
    Resolv.stubs(:getaddresses).returns(ips.map(&:to_s))
  end

  def stub_dns_failure(error = Resolv::ResolvError)
    Resolv.stubs(:getaddresses).raises(error)
  end
end
