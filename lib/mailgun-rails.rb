require "action_mailer"
require "active_support"
require "net/https"
require "uri"

module Mailgun

  class DeliveryError < StandardError
  end

  class DeliveryMethod

    attr_accessor :settings

    def initialize(settings)
      self.settings = settings
    end

    def domain
      self.settings[:domain]
    end

    def api_key
      self.settings[:api_key]
    end

    def proxy_host
      self.settings[:proxy_host] ? self.settings[:proxy_host] : nil
    end

    def proxy_port
      self.settings[:proxy_port] ? self.settings[:proxy_port] : nil
    end

    def timeout
      self.settings[:timeout] ? self.settings[:timeout] : 20
    end

    def ssl_verify_peer
      self.settings[:ssl_verify_peer]
    end

    def deliver!(mail)
      uri = URI.parse("https://api.mailgun.net/v2/#{self.domain}/messages")

      data = {
        'to'        => mail[:to].value,
        'from'      => mail[:from].value,
        'subject'   => mail.subject,
        'text'      => mail.text_part.body.raw_source,
        'html'      => mail.html_part.body.raw_source
      }

      data['cc']  = mail[:cc].value unless mail[:cc].value.blank?
      data['bcc'] = mail[:cc].value unless mail[:cc].value.blank?

      http = Net::HTTP.new(uri.host, uri.port, self.proxy_host, self.proxy_port)
      http.use_ssl      = true
      http.open_timeout = self.timeout
      http.read_timeout = self.timeout
      http.verify_mode  = OpenSSL::SSL::VERIFY_NONE if self.ssl_verify_peer == false

      request = Net::HTTP::Post.new(uri.request_uri)
      request.basic_auth("api", self.api_key)
      request.set_form_data(data)

      response = http.request(request)

      if response.message == "OK"
        mailgun_id = ActiveSupport::JSON.decode(response.body)["id"] rescue nil
        puts "MAILGUN-SENT: #{mail[:to].value} - #{mailgun_id}"
      else
        puts "MAILGUN-ERROR: #{response.body}"
        begin
          error = ActiveSupport::JSON.decode(response.body)["message"]
        rescue Exception => e
          error = "MAILGUN-ERROR #{e.to_s}"
        end
        raise Mailgun::DeliveryError.new(error)
      end

    end
  end

end

ActionMailer::Base.add_delivery_method :mailgun, Mailgun::DeliveryMethod