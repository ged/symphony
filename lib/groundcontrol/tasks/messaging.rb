#!/usr/bin/env ruby

require 'groundcontrol/task'


# A spike of Cozy's messaging back end.
class CozyMessagingService < GroundControl::Task

	# The topic key to subscribe to
	subscribe_to 'cozy.user.create',
	             'cozy.user.destroy'

	# Timeout for performing work.
	timeout 30.seconds


	TEMPLATE_MAP = %w{
		account/challenge_deposits_failed
		account/challenge_deposits_ready
		account/challenge_deposits_verified
		account/invalid
		account/need_reconfirmation
		allocations/new
		allocations/updated
		application/accepted
		application/applicant_added
		application/coapplicant
		application/new
		application/offer_accepted
		application/offer_declined
		application/offer_expired
		application/rejected
		chomper/error
		email
		email_flat
		guest_pass/guest_pass_viewed
		guest_pass/new_guest_pass
		internal/payment_failure
		invites/landlord
		payment_reminders/automatic_reminder
		payment_reminders/bank_account_verification_holdup
		payment_reminders/manual_reminder
		payment_reminders/no_account
		payment_reminders/payment_failed
		payment_reminders/payment_failed_landlord
		payment_reminders/payment_failed_other_tenant
		payment_reminders/payment_initiated_landlord
		payment_reminders/payment_initiated_tenant
		payment_reminders/payment_received
		payment_reminders/payment_settled
		payment_reminders/rent_due
		payment_reminders/rent_late
		payments/amount_change_requested
		payments/double_payment
		payments/rent_amount_changed
		payments/rent_amount_changed_roommate
		payments/request
		payments/request_cancelled
		payments/request_cancelled_landlord
		payments/request_cancelled_tenant
		pieces/button
		pieces/link
		test/yay
		test/yay.subject.erb
		users/activation
		users/beta
		users/confirm_employer_email
		users/forgot
		users/invoice_payment_failed
		users/invoice_payment_succeeded
		users/new-landlord
		users/new-tenant
		users/payments_tester
		users/signup_from_marketing
		users/testimonial_request
		users/testimonial_request_complete
		users/trial_ending
		users/unpaid
		users/verification_failed
	}

	### Set up the mailer object at startup.
	def initialize
		@cio_client = Cozy::CustomerIOClient.new
	end



	#
	# Task API
	#

	### Do the ping.
	def work( payload, metadata )

	end


end # class GroundControl::Task::Pinger

