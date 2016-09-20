# Copyright (c) 2008-2013 Michael Dvorkin and contributors.
#
# Fat Free CRM is freely distributable under the terms of MIT license.
# See MIT-LICENSE file or http://www.opensource.org/licenses/mit-license.php
#------------------------------------------------------------------------------
require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

describe OpportunitiesController do
  def get_data_for_sidebar
    @stage = Setting.unroll(:opportunity_stage)
  end

  before do
    require_user
    set_current_tab(:opportunities)
  end

  # GET /opportunities
  # GET /opportunities.xml
  #----------------------------------------------------------------------------
  describe "responding to GET index" do
    before do
      get_data_for_sidebar
    end

    it "should expose all opportunities as @opportunities and render [index] template" do
      @opportunities = [FactoryGirl.create(:opportunity, user: current_user)]

      #get :index
      get :index, params: {}
      expect(assigns[:opportunities]).to eq(@opportunities)
      expect(response).to render_template("opportunities/index")
    end

    it "should expose the data for the opportunities sidebar" do
      #get :index
      get :index, params: {}
      expect(assigns[:stage]).to eq(@stage)
      expect(assigns[:opportunity_stage_total].keys.map(&:to_sym) - (@stage.map(&:last) << :all << :other)).to eq([])
    end

    it "should filter out opportunities by stage" do
      controller.session[:opportunities_filter] = "prospecting,negotiation"
      @opportunities = [
        FactoryGirl.create(:opportunity, user: current_user, stage: "negotiation"),
        FactoryGirl.create(:opportunity, user: current_user, stage: "prospecting")
      ]
      # This one should be filtered out.
      FactoryGirl.create(:opportunity, user: current_user, stage: "analysis")

      #get :index
      get :index, params: {}
      # Note: can't compare opportunities directly because of BigDecimal objects.
      expect(assigns[:opportunities].size).to eq(2)
      expect(assigns[:opportunities].map(&:stage).sort).to eq(%w(negotiation prospecting))
    end

    it "should perform lookup using query string" do
      @first  = FactoryGirl.create(:opportunity, user: current_user, name: "The first one")
      @second = FactoryGirl.create(:opportunity, user: current_user, name: "The second one")

      #get :index, query: "second"
      get :index, params: {query:  "second"}
      expect(assigns[:opportunities]).to eq([@second])
      expect(assigns[:current_query]).to eq("second")
      expect(session[:opportunities_current_query]).to eq("second")
    end

    describe "AJAX pagination" do
      it "should pick up page number from params" do
        @opportunities = [FactoryGirl.create(:opportunity, user: current_user)]
        #xhr :get, :index, page: 42
        get :index, xhr:true, params: {page:  42}

        expect(assigns[:current_page].to_i).to eq(42)
        expect(assigns[:opportunities]).to eq([]) # page #42 should be empty if there's only one opportunity ;-)
        expect(session[:opportunities_current_page].to_i).to eq(42)
        expect(response).to render_template("opportunities/index")
      end

      it "should pick up saved page number from session" do
        session[:opportunities_current_page] = 42
        @opportunities = [FactoryGirl.create(:opportunity, user: current_user)]
        #xhr :get, :index
        get :index, xhr:true, params: {}

        expect(assigns[:current_page]).to eq(42)
        expect(assigns[:opportunities]).to eq([])
        expect(response).to render_template("opportunities/index")
      end

      it "should reset current_page when query is altered" do
        session[:opportunities_current_page] = 42
        session[:opportunities_current_query] = "bill"
        @opportunities = [FactoryGirl.create(:opportunity, user: current_user)]
        #xhr :get, :index
        get :index, xhr:true, params: {}

        expect(assigns[:current_page]).to eq(1)
        expect(assigns[:opportunities]).to eq(@opportunities)
        expect(response).to render_template("opportunities/index")
      end
    end

    describe "with mime type of JSON" do
      it "should render all opportunities as JSON" do
        expect(@controller).to receive(:get_opportunities).and_return(opportunities = double("Array of Opportunities"))
        expect(opportunities).to receive(:to_json).and_return("generated JSON")

        request.env["HTTP_ACCEPT"] = "application/json"
        #get :index
        get :index, params: {}
        expect(response.body).to eq("generated JSON")
      end
    end

    describe "with mime type of JSON" do
      it "should render all opportunities as JSON" do
        expect(@controller).to receive(:get_opportunities).and_return(opportunities = double("Array of Opportunities"))
        expect(opportunities).to receive(:to_json).and_return("generated JSON")

        request.env["HTTP_ACCEPT"] = "application/json"
        #get :index
        get :index, params: {}
        expect(response.body).to eq("generated JSON")
      end
    end

    describe "with mime type of XML" do
      it "should render all opportunities as xml" do
        expect(@controller).to receive(:get_opportunities).and_return(opportunities = double("Array of Opportunities"))
        expect(opportunities).to receive(:to_xml).and_return("generated XML")

        request.env["HTTP_ACCEPT"] = "application/xml"
        #get :index
        get :index, params: {}
        expect(response.body).to eq("generated XML")
      end
    end
  end

  # GET /opportunities/1
  # GET /opportunities/1.xml                                               HTML
  #----------------------------------------------------------------------------
  describe "responding to GET show" do
    describe "with mime type of HTML" do
      before do
        @opportunity = FactoryGirl.create(:opportunity, id: 42)
        @stage = Setting.unroll(:opportunity_stage)
        @comment = Comment.new
      end

      it "should expose the requested opportunity as @opportunity and render [show] template" do
        #get :show, id: 42
        get :show, params: {id:  42}
        expect(assigns[:opportunity]).to eq(@opportunity)
        expect(assigns[:stage]).to eq(@stage)
        expect(assigns[:comment].attributes).to eq(@comment.attributes)
        expect(response).to render_template("opportunities/show")
      end

      it "should update an activity when viewing the opportunity" do
        #get :show, id: @opportunity.id
        get :show, params: {id:  @opportunity.id}
        expect(@opportunity.versions.last.event).to eq('view')
      end
    end

    describe "with mime type of JSON" do
      it "should render the requested opportunity as JSON" do
        @opportunity = FactoryGirl.create(:opportunity, id: 42)
        expect(Opportunity).to receive(:find).and_return(@opportunity)
        expect(@opportunity).to receive(:to_json).and_return("generated JSON")

        request.env["HTTP_ACCEPT"] = "application/json"
        #get :show, id: 42
        get :show, params: {id:  42}
        expect(response.body).to eq("generated JSON")
      end
    end

    describe "with mime type of XML" do
      it "should render the requested opportunity as xml" do
        @opportunity = FactoryGirl.create(:opportunity, id: 42)
        expect(Opportunity).to receive(:find).and_return(@opportunity)
        expect(@opportunity).to receive(:to_xml).and_return("generated XML")

        request.env["HTTP_ACCEPT"] = "application/xml"
        #get :show, id: 42
        get :show, params: {id:  42}
        expect(response.body).to eq("generated XML")
      end
    end

    describe "opportunity got deleted or otherwise unavailable" do
      it "should redirect to opportunity index if the opportunity got deleted" do
        @opportunity = FactoryGirl.create(:opportunity, user: current_user)
        @opportunity.destroy

        #get :show, id: @opportunity.id
        get :show, params: {id:  @opportunity.id}
        expect(flash[:warning]).not_to eq(nil)
        expect(response).to redirect_to(opportunities_path)
      end

      it "should redirect to opportunity index if the opportunity is protected" do
        @private = FactoryGirl.create(:opportunity, user: FactoryGirl.create(:user), access: "Private")

        #get :show, id: @private.id
        get :show, params: {id:  @private.id}
        expect(flash[:warning]).not_to eq(nil)
        expect(response).to redirect_to(opportunities_path)
      end

      it "should return 404 (Not Found) JSON error" do
        @opportunity = FactoryGirl.create(:opportunity, user: current_user)
        @opportunity.destroy
        request.env["HTTP_ACCEPT"] = "application/json"

        #get :show, id: @opportunity.id
        get :show, params: {id:  @opportunity.id}
        expect(response.code).to eq("404") # :not_found
      end

      it "should return 404 (Not Found) XML error" do
        @opportunity = FactoryGirl.create(:opportunity, user: current_user)
        @opportunity.destroy
        request.env["HTTP_ACCEPT"] = "application/xml"

        #get :show, id: @opportunity.id
        get :show, params: {id:  @opportunity.id}
        expect(response.code).to eq("404") # :not_found
      end
    end
  end

  # GET /opportunities/new
  # GET /opportunities/new.xml                                             AJAX
  #----------------------------------------------------------------------------
  describe "responding to GET new" do
    it "should expose a new opportunity as @opportunity and render [new] template" do
      @opportunity = Opportunity.new(user: current_user, access: Setting.default_access, stage: "prospecting")
      @account = Account.new(user: current_user, access: Setting.default_access)
      @accounts = [FactoryGirl.create(:account, user: current_user)]

      #xhr :get, :new
      get :new, xhr:true, params: {}
      expect(assigns[:opportunity].attributes).to eq(@opportunity.attributes)
      expect(assigns[:account].attributes).to eq(@account.attributes)
      expect(assigns[:accounts]).to eq(@accounts)
      expect(response).to render_template("opportunities/new")
    end

    it "should created an instance of related object when necessary" do
      @contact = FactoryGirl.create(:contact, id: 42)

      #xhr :get, :new, related: "contact_42"
      get :new, xhr:true, params: {related:  "contact_42"}
      expect(assigns[:contact]).to eq(@contact)
    end

    describe "(when creating related opportunity)" do
      it "should redirect to parent asset's index page with the message if parent asset got deleted" do
        @account = FactoryGirl.create(:account)
        @account.destroy

        #xhr :get, :new, related: "account_#{@account.id}"
        get :new, xhr:true, params: {related:  "account_#{@account.id}"}
        expect(flash[:warning]).not_to eq(nil)
        expect(response.body).to eq('window.location.href = "/accounts";')
      end

      it "should redirect to parent asset's index page with the message if parent asset got protected" do
        @account = FactoryGirl.create(:account, access: "Private")

        #xhr :get, :new, related: "account_#{@account.id}"
        get :new, xhr:true, params: {related:  "account_#{@account.id}"}
        expect(flash[:warning]).not_to eq(nil)
        expect(response.body).to eq('window.location.href = "/accounts";')
      end
    end
  end

  # GET /opportunities/1/edit                                              AJAX
  #----------------------------------------------------------------------------
  describe "responding to GET edit" do
    it "should expose the requested opportunity as @opportunity and render [edit] template" do
      # Note: campaign => nil makes sure campaign factory is not invoked which has a side
      # effect of creating an extra (campaign) user.
      @account = FactoryGirl.create(:account, user: current_user)
      @opportunity = FactoryGirl.create(:opportunity, id: 42, user: current_user, campaign: nil,
                                                      account: @account)
      @stage = Setting.unroll(:opportunity_stage)
      @accounts = [@account]

      #xhr :get, :edit, id: 42
      get :edit, xhr:true, params: {id:  42}
      @opportunity.reload
      expect(assigns[:opportunity]).to eq(@opportunity)
      expect(assigns[:account].attributes).to eq(@opportunity.account.attributes)
      expect(assigns[:accounts]).to eq(@accounts)
      expect(assigns[:stage]).to eq(@stage)
      expect(assigns[:previous]).to eq(nil)
      expect(response).to render_template("opportunities/edit")
    end

    it "should expose previous opportunity as @previous when necessary" do
      @opportunity = FactoryGirl.create(:opportunity, id: 42)
      @previous = FactoryGirl.create(:opportunity, id: 41)

      #xhr :get, :edit, id: 42, previous: 41
      get :edit, xhr:true, params: {id:  42, previous:  41}
      expect(assigns[:previous]).to eq(@previous)
    end

    describe "opportunity got deleted or is otherwise unavailable" do
      it "should reload current page with the flash message if the opportunity got deleted" do
        @opportunity = FactoryGirl.create(:opportunity, user: current_user)
        @opportunity.destroy

        #xhr :get, :edit, id: @opportunity.id
        get :edit, xhr:true, params: {id:  @opportunity.id}
        expect(flash[:warning]).not_to eq(nil)
        expect(response.body).to eq("window.location.reload();")
      end

      it "should reload current page with the flash message if the opportunity is protected" do
        @private = FactoryGirl.create(:opportunity, user: FactoryGirl.create(:user), access: "Private")

        #xhr :get, :edit, id: @private.id
        get :edit, xhr:true, params: {id:  @private.id}
        expect(flash[:warning]).not_to eq(nil)
        expect(response.body).to eq("window.location.reload();")
      end
    end

    describe "(previous opportunity got deleted or is otherwise unavailable)" do
      before do
        @opportunity = FactoryGirl.create(:opportunity, user: current_user)
        @previous = FactoryGirl.create(:opportunity, user: FactoryGirl.create(:user))
      end

      it "should notify the view if previous opportunity got deleted" do
        @previous.destroy

        #xhr :get, :edit, id: @opportunity.id, previous: @previous.id
        get :edit, xhr:true, params: {id:  @opportunity.id, previous:  @previous.id}
        expect(flash[:warning]).to eq(nil) # no warning, just silently remove the div
        expect(assigns[:previous]).to eq(@previous.id)
        expect(response).to render_template("opportunities/edit")
      end

      it "should notify the view if previous opportunity got protected" do
        @previous.update_attribute(:access, "Private")

        #xhr :get, :edit, id: @opportunity.id, previous: @previous.id
        get :edit, xhr:true, params: {id:  @opportunity.id, previous:  @previous.id}
        expect(flash[:warning]).to eq(nil)
        expect(assigns[:previous]).to eq(@previous.id)
        expect(response).to render_template("opportunities/edit")
      end
    end
  end

  # POST /opportunities
  # POST /opportunities.xml                                                AJAX
  #----------------------------------------------------------------------------
  describe "responding to POST create" do
    describe "with valid params" do
      before do
        @opportunity = FactoryGirl.build(:opportunity, user: current_user)
        allow(Opportunity).to receive(:new).and_return(@opportunity)
        @stage = Setting.unroll(:opportunity_stage)
      end

      it "should expose a newly created opportunity as @opportunity and render [create] template" do
        #xhr :post, :create, opportunity: { name: "Hello" }, account: { name: "Hello again" }
        post :create, xhr:true, params: {opportunity:  { name: "Hello" }, account:  { name: "Hello again" }}
        expect(assigns(:opportunity)).to eq(@opportunity)
        expect(assigns(:stage)).to eq(@stage)
        expect(assigns(:opportunity_stage_total)).to be_nil
        expect(response).to render_template("opportunities/create")
      end

      it "should get sidebar data if called from opportunities index" do
        request.env["HTTP_REFERER"] = "http://localhost/opportunities"
        #xhr :post, :create, opportunity: { name: "Hello" }, account: { name: "Hello again" }
        post :create, xhr:true, params: {opportunity:  { name: "Hello" }, account:  { name: "Hello again" }}
        expect(assigns(:opportunity_stage_total)).to be_an_instance_of(HashWithIndifferentAccess)
      end

      it "should find related account if called from account landing page" do
        @account = FactoryGirl.create(:account, user: current_user)
        request.env["HTTP_REFERER"] = "http://localhost/accounts/#{@account.id}"

        #xhr :post, :create, opportunity: { name: "Hello" }, account: { id: @account.id }
        post :create, xhr:true, params: {opportunity:  { name: "Hello" }, account:  { id: @account.id }}
        expect(assigns(:account)).to eq(@account)
      end

      it "should find related campaign if called from campaign landing page" do
        @campaign = FactoryGirl.create(:campaign, user: current_user)
        request.env["HTTP_REFERER"] = "http://localhost/campaigns/#{@campaign.id}"

        #xhr :post, :create, opportunity: { name: "Hello" }, campaign: @campaign.id, account: { name: "Hello again" }
        post :create, xhr:true, params: {opportunity:  { name: "Hello" }, campaign:  @campaign.id, account:  { name: "Hello again" }}
        expect(assigns(:campaign)).to eq(@campaign)
      end

      it "should reload opportunities to update pagination if called from opportunities index" do
        request.env["HTTP_REFERER"] = "http://localhost/opportunities"
        #xhr :post, :create, opportunity: { name: "Hello" }, account: { name: "Hello again" }
        post :create, xhr:true, params: {opportunity:  { name: "Hello" }, account:  { name: "Hello again" }}
        expect(assigns[:opportunities]).to eq([@opportunity])
      end

      it "should associate opportunity with the campaign when called from campaign landing page" do
        @campaign = FactoryGirl.create(:campaign)

        request.env["HTTP_REFERER"] = "http://localhost/campaigns/#{@campaign.id}"
        #xhr :post, :create, opportunity: { name: "Hello" }, campaign: @campaign.id, account: { name: "Test Account" }
        post :create, xhr:true, params: {opportunity:  { name: "Hello" }, campaign:  @campaign.id, account:  { name: "Test Account" }}
        expect(assigns(:opportunity)).to eq(@opportunity)
        expect(assigns(:campaign)).to eq(@campaign)
        expect(@opportunity.campaign).to eq(@campaign)
      end

      it "should associate opportunity with the contact when called from contact landing page" do
        @contact = FactoryGirl.create(:contact, id: 42)

        request.env["HTTP_REFERER"] = "http://localhost/contacts/42"
        #xhr :post, :create, opportunity: { name: "Hello" }, contact: 42, account: { name: "Hello again" }
        post :create, xhr:true, params: {opportunity:  { name: "Hello" }, contact:  42, account:  { name: "Hello again" }}
        expect(assigns(:opportunity)).to eq(@opportunity)
        expect(@opportunity.contacts).to include(@contact)
        expect(@contact.opportunities).to include(@opportunity)
      end

      it "should create new account and associate it with the opportunity" do
        #xhr :put, :create, opportunity: { name: "Hello" }, account: { name: "new account" }
        put :create, xhr:true, params: {opportunity:  { name: "Hello" }, account:  { name: "new account" }}
        expect(assigns(:opportunity)).to eq(@opportunity)
        expect(@opportunity.account.name).to eq("new account")
      end

      it "should associate opportunity with the existing account" do
        @account = FactoryGirl.create(:account, id: 42)

        #xhr :post, :create, opportunity: { name: "Hello world" }, account: { id: 42 }
        post :create, xhr:true, params: {opportunity:  { name: "Hello world" }, account:  { id: 42 }}
        expect(assigns(:opportunity)).to eq(@opportunity)
        expect(@opportunity.account).to eq(@account)
        expect(@account.opportunities).to include(@opportunity)
      end

      it "should update related campaign revenue if won" do
        @campaign = FactoryGirl.create(:campaign, revenue: 0)
        @opportunity = FactoryGirl.build(:opportunity, user: current_user, stage: "won", amount: 1100, discount: 100)
        allow(Opportunity).to receive(:new).and_return(@opportunity)

        #xhr :post, :create, opportunity: { name: "Hello world" }, campaign: @campaign.id, account: { name: "Test Account" }
        post :create, xhr:true, params: {opportunity:  { name: "Hello world" }, campaign:  @campaign.id, account:  { name: "Test Account" }}
        expect(assigns(:opportunity)).to eq(@opportunity)
        expect(@opportunity.campaign).to eq(@campaign.reload)
        expect(@campaign.revenue.to_i).to eq(1000) # 1000 - 100 discount.
      end

      it "should add a new comment to the newly created opportunity when specified" do
        @opportunity = FactoryGirl.build(:opportunity, user: current_user)
        allow(Opportunity).to receive(:new).and_return(@opportunity)

        #xhr :post, :create, opportunity: { name: "Opportunity Knocks" }, account: { name: "My Account" }, comment_body: "Awesome comment is awesome"
        post :create, xhr:true, params: {opportunity:  { name: "Opportunity Knocks" }, account:  { name: "My Account" }, comment_body:  "Awesome comment is awesome"}
        expect(@opportunity.reload.comments.map(&:comment)).to include("Awesome comment is awesome")
      end
    end

    describe "with invalid params" do
      it "should expose a newly created but unsaved opportunity as @opportunity with blank @account and render [create] template" do
        @account = Account.new(user: current_user)
        @opportunity = FactoryGirl.build(:opportunity, name: nil, campaign: nil, user: current_user,
                                                       account: @account)
        allow(Opportunity).to receive(:new).and_return(@opportunity)
        @stage = Setting.unroll(:opportunity_stage)
        @accounts = [FactoryGirl.create(:account, user: current_user)]

        # Expect to redraw [create] form with blank account.
        #xhr :post, :create, opportunity: {}, account: { user_id: current_user.id }
        post :create, xhr:true, params: {opportunity:  {}, account:  { user_id: current_user.id }}
        expect(assigns(:opportunity)).to eq(@opportunity)
        expect(assigns(:account).attributes).to eq(@account.attributes)
        expect(assigns(:accounts)).to eq(@accounts)
        expect(response).to render_template("opportunities/create")
      end

      it "should expose a newly created but unsaved opportunity as @opportunity with existing @account and render [create] template" do
        @account = FactoryGirl.create(:account, id: 42, user: current_user)
        @opportunity = FactoryGirl.build(:opportunity, name: nil, campaign: nil, user: current_user,
                                                       account: @account)
        allow(Opportunity).to receive(:new).and_return(@opportunity)
        @stage = Setting.unroll(:opportunity_stage)

        # Expect to redraw [create] form with selected account.
        #xhr :post, :create, opportunity: {}, account: { id: 42, user_id: current_user.id }
        post :create, xhr:true, params: {opportunity:  {}, account:  { id: 42, user_id:  current_user.id }}
        expect(assigns(:opportunity)).to eq(@opportunity)
        expect(assigns(:account)).to eq(@account)
        expect(assigns(:accounts)).to eq([@account])
        expect(response).to render_template("opportunities/create")
      end

      it "should preserve the campaign when called from campaign landing page" do
        @campaign = FactoryGirl.create(:campaign, id: 42)

        request.env["HTTP_REFERER"] = "http://localhost/campaigns/42"
        #xhr :post, :create, opportunity: { name: nil }, campaign: 42, account: { name: "Test Account" }
        post :create, xhr:true, params: {opportunity:  { name: nil }, campaign:  42, account:  { name: "Test Account" }}
        expect(assigns(:campaign)).to eq(@campaign)
        expect(response).to render_template("opportunities/create")
      end

      it "should preserve the contact when called from contact landing page" do
        @contact = FactoryGirl.create(:contact, id: 42)

        request.env["HTTP_REFERER"] = "http://localhost/contacts/42"
        #xhr :post, :create, opportunity: { name: nil }, contact: 42, account: { name: "Test Account" }
        post :create, xhr:true, params: {opportunity:  { name: nil }, contact:  42, account:  { name: "Test Account" }}
        expect(assigns(:contact)).to eq(@contact)
        expect(response).to render_template("opportunities/create")
      end
    end
  end

  # PUT /opportunities/1
  # PUT /opportunities/1.xml                                               AJAX
  #----------------------------------------------------------------------------
  describe "responding to PUT update" do
    describe "with valid params" do
      it "should update the requested opportunity, expose it as @opportunity, and render [update] template" do
        @opportunity = FactoryGirl.create(:opportunity, id: 42)
        @stage = Setting.unroll(:opportunity_stage)

        #xhr :put, :update, id: 42, opportunity: { name: "Hello world" }, account: { name: "Test Account" }
        put :update, xhr:true, params: {id:  42, opportunity:  { name: "Hello world" }, account:  { name: "Test Account" }}
        expect(@opportunity.reload.name).to eq("Hello world")
        expect(assigns(:opportunity)).to eq(@opportunity)
        expect(assigns(:stage)).to eq(@stage)
        expect(assigns(:opportunity_stage_total)).to eq(nil)
        expect(response).to render_template("opportunities/update")
      end

      it "should get sidebar data if called from opportunities index" do
        @opportunity = FactoryGirl.create(:opportunity, id: 42)

        request.env["HTTP_REFERER"] = "http://localhost/opportunities"
        #xhr :put, :update, id: 42, opportunity: { name: "Hello world" }, account: { name: "Test Account" }
        put :update, xhr:true, params: {id:  42, opportunity:  { name: "Hello world" }, account:  { name: "Test Account" }}
        expect(assigns(:opportunity_stage_total)).to be_an_instance_of(HashWithIndifferentAccess)
      end

      it "should find related account if called from account landing page" do
        @account = FactoryGirl.create(:account, user: current_user)
        @opportunity = FactoryGirl.create(:opportunity, id: 42, account: @account)
        request.env["HTTP_REFERER"] = "http://localhost/accounts/#{@account.id}"

        #xhr :put, :update, id: 42, opportunity: { name: "Hello world" }
        put :update, xhr:true, params: {id:  42, opportunity:  { name: "Hello world" }}
        expect(assigns(:account)).to eq(@account)
      end

      it "should remove related account if blank :account param is given" do
        @account = FactoryGirl.create(:account, user: current_user)
        @opportunity = FactoryGirl.create(:opportunity, id: 42, account: @account)
        request.env["HTTP_REFERER"] = "http://localhost/accounts/#{@account.id}"

        #xhr :put, :update, id: 42, opportunity: { name: "Hello world" }, account: { id: "" }
        put :update, xhr:true, params: {id:  42, opportunity:  { name: "Hello world" }, account:  { id: "" }}
        expect(assigns(:account)).to eq(nil)
      end

      it "should find related campaign if called from campaign landing page" do
        @campaign = FactoryGirl.create(:campaign, user: current_user)
        @opportunity = FactoryGirl.create(:opportunity, id: 42, user: current_user)
        @campaign.opportunities << @opportunity
        request.env["HTTP_REFERER"] = "http://localhost/campaigns/#{@campaign.id}"

        #xhr :put, :update, id: 42, opportunity: { name: "Hello world", campaign_id: @campaign.id }, account: {}
        put :update, xhr:true, params: {id:  42, opportunity:  { name: "Hello world", campaign_id: @campaign.id }, account:  {}}
        expect(assigns(:campaign)).to eq(@campaign)
      end

      it "should be able to create an account and associate it with updated opportunity" do
        @opportunity = FactoryGirl.create(:opportunity, id: 42)

        #xhr :put, :update, id: 42, opportunity: { name: "Hello" }, account: { name: "new account" }
        put :update, xhr:true, params: {id:  42, opportunity:  { name: "Hello" }, account:  { name: "new account" }}
        expect(assigns[:opportunity]).to eq(@opportunity)
        expect(assigns[:opportunity].account).not_to be_nil
        expect(assigns[:opportunity].account.name).to eq("new account")
      end

      it "should be able to create an account and associate it with updated opportunity" do
        @old_account = FactoryGirl.create(:account, id: 111)
        @new_account = FactoryGirl.create(:account, id: 999)
        @opportunity = FactoryGirl.create(:opportunity, id: 42, account: @old_account)

        #xhr :put, :update, id: 42, opportunity: { name: "Hello" }, account: { id: 999 }
        put :update, xhr:true, params: {id:  42, opportunity:  { name: "Hello" }, account:  { id: 999 }}
        expect(assigns[:opportunity]).to eq(@opportunity)
        expect(assigns[:opportunity].account).to eq(@new_account)
      end

      it "should update opportunity permissions when sharing with specific users" do
        @opportunity = FactoryGirl.create(:opportunity, id: 42, access: "Public")

        #xhr :put, :update, id: 42, opportunity: { name: "Hello", access: "Shared", user_ids: [7, 8] }, account: { name: "Test Account" }
        put :update, xhr:true, params: {id:  42, opportunity:  { name: "Hello", access: "Shared", user_ids: [7, 8] }, account:  { name: "Test Account" }}
        expect(assigns[:opportunity].access).to eq("Shared")
        expect(assigns[:opportunity].user_ids.sort).to eq([7, 8])
      end

      it "should reload opportunity campaign if called from campaign landing page" do
        @campaign = FactoryGirl.create(:campaign)
        @opportunity = FactoryGirl.create(:opportunity, campaign: @campaign)

        request.env["HTTP_REFERER"] = "http://localhost/campaigns/#{@campaign.id}"
        #xhr :put, :update, id: @opportunity.id, opportunity: { name: "Hello" }, account: { name: "Test Account" }
        put :update, xhr:true, params: {id:  @opportunity.id, opportunity:  { name: "Hello" }, account:  { name: "Test Account" }}
        expect(assigns[:campaign]).to eq(@campaign)
      end

      describe "updating campaign revenue (same campaign)" do
        it "should add to actual revenue when opportunity is closed/won" do
          @campaign = FactoryGirl.create(:campaign, revenue: 1000)
          @opportunity = FactoryGirl.create(:opportunity, campaign: @campaign, stage: 'prospecting', amount: 1100, discount: 100)

          #xhr :put, :update, id: @opportunity, opportunity: { stage: "won" }, account: { name: "Test Account" }
          put :update, xhr:true, params: {id:  @opportunity, opportunity:  { stage: "won" }, account:  { name: "Test Account" }}
          expect(@campaign.reload.revenue.to_i).to eq(2000) # 1000 -> 2000
        end

        it "should substract from actual revenue when opportunity is no longer closed/won" do
          @campaign = FactoryGirl.create(:campaign, revenue: 1000)
          @opportunity = FactoryGirl.create(:opportunity, campaign: @campaign, stage: "won", amount: 1100, discount: 100)
          # @campaign.revenue is now $2000 since we created winning opportunity.

          #xhr :put, :update, id: @opportunity, opportunity: { stage: 'prospecting' }, account: { name: "Test Account" }
          put :update, xhr:true, params: {id:  @opportunity, opportunity:  { stage: 'prospecting' }, account:  { name: "Test Account" }}
          expect(@campaign.reload.revenue.to_i).to eq(1000) # Should be adjusted back to $1000.
        end

        it "should not update actual revenue when opportunity is not closed/won" do
          @campaign = FactoryGirl.create(:campaign, revenue: 1000)
          @opportunity = FactoryGirl.create(:opportunity, campaign: @campaign, stage: 'prospecting', amount: 1100, discount: 100)

          #xhr :put, :update, id: @opportunity, opportunity: { stage: "lost" }, account: { name: "Test Account" }
          put :update, xhr:true, params: {id:  @opportunity, opportunity:  { stage: "lost" }, account:  { name: "Test Account" }}
          expect(@campaign.reload.revenue.to_i).to eq(1000) # Stays the same.
        end
      end

      describe "updating campaign revenue (diferent campaigns)" do
        it "should update newly assigned campaign when opportunity is closed/won" do
          @campaigns = { old: FactoryGirl.create(:campaign, revenue: 1000), new: FactoryGirl.create(:campaign, revenue: 1000) }
          @opportunity = FactoryGirl.create(:opportunity, campaign: @campaigns[:old], stage: 'prospecting', amount: 1100, discount: 100)

          #xhr :put, :update, id: @opportunity, opportunity: { stage: "won", campaign_id: @campaigns[:new].id }, account: { name: "Test Account" }
          put :update, xhr:true, params: {id:  @opportunity, opportunity:  { stage: "won", campaign_id: @campaigns[:new].id }, account:  { name: "Test Account" }}

          expect(@campaigns[:old].reload.revenue.to_i).to eq(1000) # Stays the same.
          expect(@campaigns[:new].reload.revenue.to_i).to eq(2000) # 1000 -> 2000
        end

        it "should update old campaign when opportunity is no longer closed/won" do
          @campaigns = { old: FactoryGirl.create(:campaign, revenue: 1000), new: FactoryGirl.create(:campaign, revenue: 1000) }
          @opportunity = FactoryGirl.create(:opportunity, campaign: @campaigns[:old], stage: "won", amount: 1100, discount: 100)
          # @campaign.revenue is now $2000 since we created winning opportunity.

          #xhr :put, :update, id: @opportunity, opportunity: { stage: 'prospecting', campaign_id: @campaigns[:new].id }, account: { name: "Test Account" }
          put :update, xhr:true, params: {id:  @opportunity, opportunity:  { stage: 'prospecting', campaign_id: @campaigns[:new].id }, account:  { name: "Test Account" }}
          expect(@campaigns[:old].reload.revenue.to_i).to eq(1000) # Should be adjusted back to $1000.
          expect(@campaigns[:new].reload.revenue.to_i).to eq(1000) # Stays the same.
        end

        it "should not update campaigns when opportunity is not closed/won" do
          @campaigns = { old: FactoryGirl.create(:campaign, revenue: 1000), new: FactoryGirl.create(:campaign, revenue: 1000) }
          @opportunity = FactoryGirl.create(:opportunity, campaign: @campaigns[:old], stage: 'prospecting', amount: 1100, discount: 100)

          #xhr :put, :update, id: @opportunity, opportunity: { stage: "lost", campaign_id: @campaigns[:new].id }, account: { name: "Test Account" }
          put :update, xhr:true, params: {id:  @opportunity, opportunity:  { stage: "lost", campaign_id: @campaigns[:new].id }, account:  { name: "Test Account" }}
          expect(@campaigns[:old].reload.revenue.to_i).to eq(1000) # Stays the same.
          expect(@campaigns[:new].reload.revenue.to_i).to eq(1000) # Stays the same.
        end
      end

      describe "opportunity got deleted or otherwise unavailable" do
        it "should reload current page with the flash message if the opportunity got deleted" do
          @opportunity = FactoryGirl.create(:opportunity, user: current_user)
          @opportunity.destroy

          #xhr :put, :update, id: @opportunity.id
          put :update, xhr:true, params: {id:  @opportunity.id}
          expect(flash[:warning]).not_to eq(nil)
          expect(response.body).to eq("window.location.reload();")
        end

        it "should reload current page with the flash message if the opportunity is protected" do
          @private = FactoryGirl.create(:opportunity, user: FactoryGirl.create(:user), access: "Private")

          #xhr :put, :update, id: @private.id
          put :update, xhr:true, params: {id:  @private.id}
          expect(flash[:warning]).not_to eq(nil)
          expect(response.body).to eq("window.location.reload();")
        end
      end
    end

    describe "with invalid params" do
      it "should not update the requested opportunity but still expose it as @opportunity, and render [update] template" do
        @opportunity = FactoryGirl.create(:opportunity, id: 42, name: "Hello people")

        #xhr :put, :update, id: 42, opportunity: { name: nil }, account: { name: "Test Account" }
        put :update, xhr:true, params: {id:  42, opportunity:  { name: nil }, account:  { name: "Test Account" }}
        expect(@opportunity.reload.name).to eq("Hello people")
        expect(assigns(:opportunity)).to eq(@opportunity)
        expect(assigns(:opportunity_stage_total)).to eq(nil)
        expect(response).to render_template("opportunities/update")
      end

      it "should expose existing account as @account if selected" do
        @account = FactoryGirl.create(:account, id: 99)
        @opportunity = FactoryGirl.create(:opportunity, id: 42)
        FactoryGirl.create(:account_opportunity, account: @account, opportunity: @opportunity)

        #xhr :put, :update, id: 42, opportunity: { name: nil }, account: { id: 99 }
        put :update, xhr:true, params: {id:  42, opportunity:  { name: nil }, account:  { id: 99 }}
        expect(assigns(:account)).to eq(@account)
      end
    end
  end

  # DELETE /opportunities/1
  # DELETE /opportunities/1.xml                                            AJAX
  #----------------------------------------------------------------------------
  describe "responding to DELETE destroy" do
    before do
      @opportunity = FactoryGirl.create(:opportunity, user: current_user)
    end

    describe "AJAX request" do
      it "should destroy the requested opportunity and render [destroy] template" do
        #xhr :delete, :destroy, id: @opportunity.id
        delete :destroy, xhr:true, params: {id:  @opportunity.id}

        expect { Opportunity.find(@opportunity.id) }.to raise_error(ActiveRecord::RecordNotFound)
        expect(assigns(:opportunity_stage_total)).to eq(nil)
        expect(response).to render_template("opportunities/destroy")
      end

      describe "when called from Opportunities index page" do
        before do
          request.env["HTTP_REFERER"] = "http://localhost/opportunities"
        end

        it "should get sidebar data if called from opportunities index" do
          #xhr :delete, :destroy, id: @opportunity.id
          delete :destroy, xhr:true, params: {id:  @opportunity.id}
          expect(assigns(:opportunity_stage_total)).to be_an_instance_of(HashWithIndifferentAccess)
        end

        it "should try previous page and render index action if current page has no opportunities" do
          session[:opportunities_current_page] = 42

          #xhr :delete, :destroy, id: @opportunity.id
          delete :destroy, xhr:true, params: {id:  @opportunity.id}
          expect(session[:opportunities_current_page]).to eq(41)
          expect(response).to render_template("opportunities/index")
        end

        it "should render index action when deleting last opportunity" do
          session[:opportunities_current_page] = 1

          #xhr :delete, :destroy, id: @opportunity.id
          delete :destroy, xhr:true, params: {id:  @opportunity.id}
          expect(session[:opportunities_current_page]).to eq(1)
          expect(response).to render_template("opportunities/index")
        end
      end

      describe "when called from related asset page" do
        it "should reset current page to 1" do
          request.env["HTTP_REFERER"] = "http://localhost/accounts/123"

          #xhr :delete, :destroy, id: @opportunity.id
          delete :destroy, xhr:true, params: {id:  @opportunity.id}
          expect(session[:opportunities_current_page]).to eq(1)
          expect(response).to render_template("opportunities/destroy")
        end

        it "should reload campaiign to be able to refresh its summary" do
          @account = FactoryGirl.create(:account)
          @opportunity = FactoryGirl.create(:opportunity, user: current_user, account: @account)
          request.env["HTTP_REFERER"] = "http://localhost/accounts/#{@account.id}"

          #xhr :delete, :destroy, id: @opportunity.id
          delete :destroy, xhr:true, params: {id:  @opportunity.id}
          expect(assigns[:account]).to eq(@account)
          expect(response).to render_template("opportunities/destroy")
        end

        it "should reload campaiign to be able to refresh its summary" do
          @campaign = FactoryGirl.create(:campaign)
          @opportunity = FactoryGirl.create(:opportunity, user: current_user, campaign: @campaign)
          request.env["HTTP_REFERER"] = "http://localhost/campaigns/#{@campaign.id}"

          #xhr :delete, :destroy, id: @opportunity.id
          delete :destroy, xhr:true, params: {id:  @opportunity.id}
          expect(assigns[:campaign]).to eq(@campaign)
          expect(response).to render_template("opportunities/destroy")
        end
      end

      describe "opportunity got deleted or otherwise unavailable" do
        it "should reload current page is the opportunity got deleted" do
          @opportunity = FactoryGirl.create(:opportunity, user: current_user)
          @opportunity.destroy

          #xhr :delete, :destroy, id: @opportunity.id
          delete :destroy, xhr:true, params: {id:  @opportunity.id}
          expect(flash[:warning]).not_to eq(nil)
          expect(response.body).to eq("window.location.reload();")
        end

        it "should reload current page with the flash message if the opportunity is protected" do
          @private = FactoryGirl.create(:opportunity, user: FactoryGirl.create(:user), access: "Private")

          #xhr :delete, :destroy, id: @private.id
          delete :destroy, xhr:true, params: {id:  @private.id}
          expect(flash[:warning]).not_to eq(nil)
          expect(response.body).to eq("window.location.reload();")
        end
      end
    end

    describe "HTML request" do
      it "should redirect to Opportunities index when an opportunity gets deleted from its landing page" do
        #delete :destroy, id: @opportunity.id
        delete :destroy, params: {id:  @opportunity.id}
        expect(flash[:notice]).not_to eq(nil)
        expect(response).to redirect_to(opportunities_path)
      end

      it "should redirect to opportunity index with the flash message is the opportunity got deleted" do
        @opportunity = FactoryGirl.create(:opportunity, user: current_user)
        @opportunity.destroy

        #delete :destroy, id: @opportunity.id
        delete :destroy, params: {id:  @opportunity.id}
        expect(flash[:warning]).not_to eq(nil)
        expect(response).to redirect_to(opportunities_path)
      end

      it "should redirect to opportunity index with the flash message if the opportunity is protected" do
        @private = FactoryGirl.create(:opportunity, user: FactoryGirl.create(:user), access: "Private")

        #delete :destroy, id: @private.id
        delete :destroy, params: {id:  @private.id}
        expect(flash[:warning]).not_to eq(nil)
        expect(response).to redirect_to(opportunities_path)
      end
    end
  end

  # PUT /opportunities/1/attach
  # PUT /opportunities/1/attach.xml                                        AJAX
  #----------------------------------------------------------------------------
  describe "responding to PUT attach" do
    describe "tasks" do
      before do
        @model = FactoryGirl.create(:opportunity)
        @attachment = FactoryGirl.create(:task, asset: nil)
      end
      it_should_behave_like("attach")
    end

    describe "contacts" do
      before do
        @model = FactoryGirl.create(:opportunity)
        @attachment = FactoryGirl.create(:contact)
      end
      it_should_behave_like("attach")
    end
  end

  # POST /opportunities/1/discard
  # POST /opportunities/1/discard.xml                                      AJAX
  #----------------------------------------------------------------------------
  describe "responding to POST discard" do
    describe "tasks" do
      before do
        @model = FactoryGirl.create(:opportunity)
        @attachment = FactoryGirl.create(:task, asset: @model)
      end
      it_should_behave_like("discard")
    end

    describe "contacts" do
      before do
        @attachment = FactoryGirl.create(:contact)
        @model = FactoryGirl.create(:opportunity)
        @model.contacts << @attachment
      end
      it_should_behave_like("discard")
    end
  end

  # POST /opportunities/auto_complete/query                                AJAX
  #----------------------------------------------------------------------------
  describe "responding to POST auto_complete" do
    before do
      @auto_complete_matches = [FactoryGirl.create(:opportunity, name: "Hello World", user: current_user)]
    end

    it_should_behave_like("auto complete")
  end

  # GET /opportunities/redraw                                              AJAX
  #----------------------------------------------------------------------------
  describe "responding to GET redraw" do
    it "should save user selected opportunity preference" do
      #xhr :get, :redraw, per_page: 42, view: "brief", sort_by: "name"
      get :redraw, xhr:true, params: {per_page:  42, view:  "brief", sort_by:  "name"}
      expect(current_user.preference[:opportunities_per_page]).to eq("42")
      expect(current_user.preference[:opportunities_index_view]).to eq("brief")
      expect(current_user.preference[:opportunities_sort_by]).to eq("opportunities.name ASC")
    end

    it "should reset current page to 1" do
      #xhr :get, :redraw, per_page: 42, view: "brief", sort_by: "name"
      get :redraw, xhr:true, params: {per_page:  42, view:  "brief", sort_by:  "name"}
      expect(session[:opportunities_current_page]).to eq(1)
    end

    it "should select @opportunities and render [index] template" do
      @opportunities = [
        FactoryGirl.create(:opportunity, name: "A", user: current_user),
        FactoryGirl.create(:opportunity, name: "B", user: current_user)
      ]

      #xhr :get, :redraw, per_page: 1, sort_by: "name"
      get :redraw, xhr:true, params: {per_page:  1, sort_by:  "name"}
      expect(assigns(:opportunities)).to eq([@opportunities.first])
      expect(response).to render_template("opportunities/index")
    end
  end

  # POST /opportunities/filter                                             AJAX
  #----------------------------------------------------------------------------
  describe "responding to GET filter" do
    it "should expose filtered opportunities as @opportunity and render [filter] template" do
      session[:opportunities_filter] = "negotiation,analysis"
      @opportunities = [FactoryGirl.create(:opportunity, stage: "prospecting", user: current_user)]
      @stage = Setting.unroll(:opportunity_stage)

      #xhr :get, :filter, stage: "prospecting"
      get :filter, xhr:true, params: {stage:  "prospecting"}
      expect(assigns(:opportunities)).to eq(@opportunities)
      expect(assigns[:stage]).to eq(@stage)
      expect(response).to be_a_success
      expect(response).to render_template("opportunities/index")
    end

    it "should reset current page to 1" do
      @opportunities = []
      #xhr :get, :filter, status: "new"
      get :filter, xhr:true, params: {status:  "new"}

      expect(session[:opportunities_current_page]).to eq(1)
    end
  end
end
