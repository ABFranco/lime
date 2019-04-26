class ResourcesController < ApplicationController
  def resource_params
    params.permit(
                  :title, :url, :contact_email, :location, :population_focuses, :campuses,
                  :colleges, :availabilities, :innovation_stages, :topics, :technologies,
                  :types, :audiences, :desc, :approval_status, :flagged, :flagged_comment, 
                  :contact_name, :contact_phone, :client_tags, :resource_email, :resource_phone, 
                  :address, :deadline, :notes, :funding_amount, :approved_by, :order_by,

                  types: [], colleges: [], audiences: [], campuses: [], client_tags: [], innovation_stages: [],
                  population_focuses: [], availabilities: [], topics: [], technologies: []
                 )
  end

  before_action :set_user

  def has_many_value_hash
    {
        'types' => Type.get_values,
        'audiences' => Audience.get_values,
        'campuses' => Campus.get_values,
        'client_tags' => ClientTag.get_values,
        'innovation_stages' => InnovationStage.get_values,
        'population_focuses' => PopulationFocus.get_values,
        'availabilities' => Availability.get_values,
        'topics' => Topic.get_values,
        'technologies' => Technology.get_values
    }
  end

  def get_locations
    {
        'location' => Location.get_values,
    }
  end

  # assumes API GET request in this format :
  # GET /resources?types=Events,Mentoring&audiences=Undergraduate,Graduate&sort_by=title
  # GET /resources?title=Feminist Research Institute
  def index
    if @user.nil?
      params[:approval_status] = 1 # only admins can view unapproved resources
    end

    sort_by = params[:sort_by]
    exclusive = params[:exclusive]
    @resources = Resource.location_helper(resource_params.merge({:exclusive => exclusive}))

    if @resources != nil
       @resources = @resources.order(sort_by)
    end

    @has_many_hash = self.has_many_value_hash

    respond_to do |format|
      format.json {render :json => @resources.to_json(:include => Resource.include_has_many_params)}
      format.html
    end
  end

  def show
    id = params[:id]
    @resource = Resource.find_by_id(id)
    # only admins can see unapproved resources
    # if @user.nil? and @resource&.approval_status == 0
    #   @resource = nil
    # end

    respond_to do |format|
      format.json {render :json => @resource.to_json(:include => Resource.include_has_many_params) }
      format.html
    end
  end


  def new
    @has_many_hash = self.has_many_value_hash
    @locations = self.get_locations
    @session = session
    render template: "resources/new.html.erb"
    # render "resources/new"
  end

  def create
    #this should check any of the params are missing via validation and set an instance variable equal to the missing fields
    #otherwise add a new object to the database
    reset_session
    @desc_too_long = false
    @missing = []
    Resource.get_required_resources.each do |r|
      if !params.include?(r) or params[r] == ""
        @missing.append r
      end
    end
    #@missing = !((Resource.get_required_resources & params.keys).sort == Resource.get_required_resources.sort)
    if @missing.length > 0
      flash[:notice] = "Please fill in the required fields."
      params.each do |key, val|
        session[key] = params[key]
      end
      redirect_to :controller => 'resources', :action => 'new'
      return
    end
    if params[:desc] != nil and params[:desc].length > 500
      @desc_too_long = true
    end
    if @desc_too_long
      flash[:notice] = "Description was too long."
      params.each do |key, val|
        session[key] = params[key]
      end
      redirect_to :controller => 'resources', :action => 'new'
      return
    end

    flash[:notice] = "Your resource has been successfully submitted and will be reviewed!"

    # https://stackoverflow.com/questions/18369592/modify-ruby-hash-in-place-rails-strong-params
    rp = resource_params
    rp[:approval_status] = @user == nil ? 0 : 1
    @resource = Resource.create_resource(rp)

    respond_to do |format|
      format.json {render :json => @resource.to_json(:include => Resource.include_has_many_params) }
      format.html {redirect_to :controller => 'resources', :action => 'new'}
    end

  end

  def update
    @resource = Resource.find_by(id: params[:id])
    if @resource == nil
      flash[:notice] = "This resource does not exist"
      return
    end
    # Don't let guests update anything unless the params are "allowed"
    if !Resource.guest_update_params_allowed?(resource_params) and @user == nil
      flash[:notice] = "You don't have permissions to update records"
      # puts "You don't have permissions to update records"
      return
    end

    if params[:flagged]
      params[:flagged] = params[:flagged].to_i
      @edit = Edit.new(:resource_id => params[:id], :user => @user, :parameter => params[:flagged])
      @edit.save!
    end
    if params[:flagged_comment]
      params[:flagged_comment] = params[:flagged_comment].to_s
    end
    if params[:approval_status]
      params[:approval_status] = params[:approval_status].to_i
      @edit = Edit.new(:resource_id => params[:id], :user => @user, :parameter => params[:approval_status])
      @edit.save!
    end
    if params[:title]
      params[:title] = params[:title].to_s
      @edit = Edit.new(:resource_id => params[:id], :user => @user, :parameter => params[:title])
      @edit.save!
    end
    if params[:url]
      params[:url] = params[:url].to_s
      @edit = Edit.new(:resource_id => params[:id], :user => @user, :parameter => params[:url])
      @edit.save!
    end
    if params[:contact_email]
      params[:contact_email] = params[:contact_email].to_s
      @edit = Edit.new(:resource_id => params[:id], :user => @user, :parameter => params[:contact_email])
      @edit.save!
    end
    if params[:location]
      params[:location] = params[:location].to_s
      @edit = Edit.new(:resource_id => params[:id], :user => @user, :parameter => params[:location])
      @edit.save!
    end

    Resource.update_resource(params[:id], resource_params)
    @resource = Resource.find(params[:id])

    respond_to do |format|
      format.json {render :json => @resource.to_json(:include => Resource.include_has_many_params) }
      format.html
    end
  end

  def approve_many
    if @user.nil?
      approve_many_sad_path("This action is unauthorized.", 401)
      return
    end

    lst = params[:approve_list]
    status = params[:approval_status]
    if not status.nil?
      status = status.to_i
    else
      status = 1
    end
    if not [0, 1].include? status
      approve_many_sad_path("Approval status must be either 0 or 1.", 403)
      return
    end

    if lst == 'all'
      Resource.where(:approval_status => 0).each do |resource|
        Resource.update(resource.id, :approval_status => status)
      end
      @resources = Resource.all
    else
      lst = lst.split(',')
      if (lst.length <= 1 or lst.any? {|id| not id.scan(/\D/).empty?})
        approve_many_sad_path("Approval list not formatted correctly.", 400)
        return
      else
        @resources = []
        lst.each do |id|
          if Resource.exists? :id => id
            @resources << Resource.update(id, :approval_status => status)
          end
        end
      end
    end
    respond_to do |format|
      format.json {render :json => @resources.to_json(:include => Resource.include_has_many_params) }
      format.html {redirect_to "/resources"}
    end
  end

  def edit
    respond_to do |format|
      format.json {redirect_to "/resources/" + params[:id] + "/edit.html" }
      format.html {}
    end
  end

  def destroy

  end
  
  private
  def set_user
    if request.format.json? and params.include? :api_key
      @user = User.where(:api_token => params[:api_key]).first
    else
      @user = current_user
    end
    params.delete :api_key
  end

  def approve_many_sad_path(notice, code)
    respond_to do |format|
      format.html {
        flash[:notice] = notice
        redirect_to "/resources/approve/many.html"
      }
      format.json { render status: code, json: {}.to_json }
    end
  end

  
end
