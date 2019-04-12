class MyprofileController < CpController
  before_filter :deny_banned

  # protected
  def index
    @user = current_user
    @package = nil
    if @user.subscriptions.nil? || @user.subscriptions.size == 0
      @subscription = nil
    else
      @subscription = @user.subscriptions.current
      @package = Package.unscoped.where("id = ?", @subscription.package_id).first
    end
    
    
    #@subscriptions = Subscription.unscoped.where("user_id = ?", @user.id).order("id desc")
     
  end
  
  def home
    @user_email = current_user.email
    sep = SearchEmailParam.new({"email" => @user_email})
    @email_quer_string = sep.to_self_url_query_string

    all_orders = current_user.orders_with_report_purchased
    @reports = all_orders[0,5]
  end
  
  
  def reports
    @orders = current_user.orders_with_report_purchased    
  end
  
  def unsubscribe 
  end
  
  def edit_card
    @user = current_user
    @cc = CreditCard.new
    @current_cc = @user.credit_card
    if @current_cc.nil?
      return
    end     
  end

  def buy_subscription
    @user = current_user
    @cc = CreditCard.new
    @current_cc = @user.credit_card
    if @current_cc.nil?
      return
    end  
  end

  def update_card
    @user = current_user
    @current_cc = @user.credit_card
    @cc =  CreditCard.new(credit_cards_params)    
    
    
    #1. validation
    if !@cc.valid?
      render :edit_card
      return
    end
    
    s = @user.subscriptions.current
    if s.nil? || !s.cancelled_at.nil?
      flash.alert = Constants.error_message(Constants::VALID_UPDATE_CARD_WITHOUT_SUBBSCRIPTION_ID) + "[#{Constants::VALID_UPDATE_CARD_WITHOUT_SUBBSCRIPTION_ID}]"
      render "edit_card"
      return        
    end
    
    #2. call gateway and return if connection error
    gp = PaymentGateway.new
    gp.update_card(@user, s, @cc)
    
    if gp.connection_error
      flash.alert = Constants.error_message(Constants::GG_HTTP_CONNECTION_ERROR_ID) + "[#{Constants::GG_HTTP_CONNECTION_ERROR_ID}]"
      render "edit_card"
      return        
    end
    
    #3. parse response    
    response = Pg::UpdateCardResponse.new(gp.options)
    
    if response.successful?      
      @current_cc.active = false
      @current_cc.force_save
      @cc.active = true;
      @cc.save
      @user.credit_card_id = @cc.id
      @user.save
      if response.payment_happened?
        payment = response.build_payment
        payment.credit_card_number = @cc.card_number
        payment.subscription_id = s.id
        payment.email = @user.email
        payment.save
        s.suspended_at = nil
        s.save
        @user.update_subscribed_state(s)
        @user.save        
      end
       flash.notice = "You credit card has been updated."    
    else
      flash.alert = response.get_error_message
      render "edit_card"
      return              
    end
    
    redirect_to my_account_path
    return       
    
    # @user.stripe_token = params[:user][:stripe_token]
    # if @user.save
    #   redirect_to edit_user_registration_path, :notice => 'Updated card.'
    # else
    #   flash.alert = 'Unable to update card.'
    #   render :edit
    # end
  end  
  
  def credit_cards_params
    params.require(:credit_card).permit(:name_on_card, :card_number, :cvv, :expire_month, :expire_year, :price, :total_price)
  end  
end
