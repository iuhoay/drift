class FounderWelcomeMailer < ApplicationMailer
  # from/reply_to are the founder's own address so replies reach them directly,
  # not the app's no-reply mailbox.
  FROM_ADDRESS = ENV.fetch("FOUNDER_EMAIL", "jack@rdrift.app")
  FROM_NAME    = ENV.fetch("FOUNDER_NAME", "Jack")

  def welcome(user)
    return unless user.verified?

    mail to: user.email_address,
         from: "#{FROM_NAME} <#{FROM_ADDRESS}>",
         reply_to: FROM_ADDRESS,
         subject: "Thanks for trying Drift"
  end
end
