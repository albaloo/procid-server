class SendjsonController < ApplicationController
	skip_before_filter :verify_authenticity_token
	@@data = Rails.root.to_s+'/input.json'

	def receive
		#render :json => @data, :callback =>params[:callback]
	end

end
