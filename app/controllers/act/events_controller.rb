##
# Controller pro přihlašování se na akce
#
# VISIBLE_STATUSES:
# 'everyone'
# 'user'
# 'org'

require 'pdf_forms'
require 'json'
require 'csv'
require 'prawn'
require 'prawn/table'

PAPER_TEMPLATES_DIR = "var/act/paper-templates"


class Act::EventsController < ActController

  ##
  # GET /event/index
  #
  # Úvodní stránka k přihlašování na akce obecně
  #
  # *Provides*
  # @future_events::     všechny akce, které se budou konat (seřazené)
  # @past_evens::        všechny akce, které už se konaly (seřazené)
  # @event_category::    o jaký typ akce se jedná? (Act::Event::CATEGORIES)
  # @enroll_status::     jakým způsobem jsem na tu akci přihlášený? (yes, no, maybe) + (ev, nvt)
  #
  def index
    @breadcrumb = [ [ _breadcrumb_events ] ]
    @event_category = params[:event_category]
    if @event_category.nil?
      @event_category = "all"
    end

    @breadcrumb.push [ _breadcrumb_event_category(@event_category) ] unless @event_category == 'all'

    @enroll_status = params[:enroll_status]
    unless @enroll_status && Act::Participant.has_participant?(current_user)
      @enroll_status = "all"
    end

    args_future, args_past = Act::Event::generate_sql(Act::Participant::get_participant(current_user), @event_category, @enroll_status)

    @future_events = Act::Event.find_by_sql(args_future)
    @past_events = Act::Event.find_by_sql(args_past)
  end

  ##
  # GET /event/:event_id/show
  #
  # Úvodní stránka k vybrané akci
  #
  # *Params*
  # event_id:: O jakou akci se jedná
  #
  # *Provides*
  # *num_p_yes:: kolik účastníků (nikoliv náhradníků) je přihlášných s tím, že si jsou jistí, že jedou
  # @already_happened:: jestli se ten event již odehrál
  # @participants_yes:: účastníci (nikoliv náhradníci), kteří jedou
  # @participants_maybe:: účastníci (nikoliv náhradníci), kteří si nejsou jistí
  # @participants_no:: účastníci (nikoliv náhradníci), kteří nejedou
  # @substitutes_yes:: náhradníci (nikoliv účastníci), kteří jedou
  # @substitutes_maybe:: náhradníci (nikoliv účastníci), kteří si nejsou jistí
  # @substitutes_no:: náhradníci (nikoliv účastníci), kteří nejedou
  #
  def show
    return unless _find_event(params[:event_id])
    @event_tab = 'show'
    @breadcrumb = []
    @breadcrumb.push [ _breadcrumb_events ]
    @breadcrumb.push [ _breadcrumb_event_category(@event.event_category) ]
    @breadcrumb.push [ _breadcrumb_event(@event) ]

    if Act::Participant::has_participant?(current_user)
      @event_participant = Act::EventParticipant.find_by(event_id: params[:event_id], participant_id: Act::Participant::participant_id(current_user))
      unless @event_participant
        @event_participant = Act::EventParticipant.new
      end
      @event_participant.tshirt = current_user.participant.tshirt if @event_participant.tshirt.blank?
    end

    @num_p_yes = @event.num_signed("yes", false, true, "participant")
    @num_s_yes = @event.num_signed("yes", false, true, "substitute")

    @already_happened = @event.event_end < Date.current

    _get_participants()
    _filter_orgs()
    _filter_parts()
  end

  ##
  # POST /event/:event_id/enroll
  #
  # Vytvoří nebo upraví přihlášku
  #
  # *Params*
  # event_id:: O jakou akci se jedná
  # event_participant_params[]:: parametry přihlášky
  #
  # *Provides*
  # @event_participant:: daná přihláška
  #
  # *Redirect* @event_participant.event
  #
  def enroll
    return unless _find_event(params[:event_id])
    _get_participants()
    _filter_orgs()
    _filter_parts()

    @event_participant = Act::EventParticipant.find_by(event_id: params[:event_id], participant_id: Act::Participant::participant_id(current_user))
    if @event_participant
      participant_copy = @event_participant.dup
      @event_participant.update_chosen()

      if @event_participant.update(event_participant_params)
        if Act::EventParticipant::mail_change?(participant_copy, @event_participant)
          _send_bonz_org(@event_participant.event.bonz_org, @event_participant, false)
          _send_bonz_parent(@event_participant.participant.parent_email, @event_participant, false) if @event_participant.event.bonz_parent?
        end
        add_success "Tvoje " + (@event_participant.org? ? "(orgovská) " : (@event_participant.participant? ? "(účastnická) " : "(náhradnická) ")) + "přihláška byla úspěšně změněna"
        return redirect_to @event_participant.event
      else
        return render :show, status: :unprocessable_entity
      end
    else
      @event_participant = Act::EventParticipant.new(event_participant_params)
      @event_participant.update_chosen()
      if @event_participant.save
        _send_bonz_org(@event_participant.event.bonz_org, @event_participant, true)
        _send_bonz_parent(@event_participant.participant.parent_email, @event_participant, true) if @event_participant.event.bonz_parent?
        add_success "Byl jsi úspěšně přihlášen " + (@event_participant.org? ? "(jakožto org) " : (@event_participant.participant? ? "(jakožto účastník)" : "(jakožto náhradník)"))
        return redirect_to Act::Event.find(params[:event_id])
      else
        return render :show, status: :unprocessable_entity
      end
    end
  end

  ##
  # GET /event/new
  #
  # Formulář pro novou akci
  #
  # *Provides*
  # @event:: nová akce
  #
  def new
    @breadcrumb = []
    @breadcrumb.push [ _breadcrumb_events ]
    #@breadcrumb.push [ _breadcrumb_event_category(@event.event_category) ]
    @breadcrumb.push [ _breadcrumb_event_new ]

    return render 'permission_denied', :locals => { :desired => "vytvářet nové " } unless can? :create, Act::Event

    @event = Act::Event.new
  end

  ##
  #  POST /act/events/create
  #
  # Vytvoří novou akci
  #
  # *Params*
  # event_params[]:: parametry upravované akce
  #
  # *Redirect* @event
  def create
    return render 'permission_denied', :locals => { :desired => "vytvářet nové " } unless can? :create, Act::Event

    @event = Act::Event.new(event_params)

    if @event.save
      add_success "Akce úspěšně vytvořena"
      redirect_to @event
    else
      render :new, status: :unprocessable_entity
    end
  end


  ##
  #  GET /act/events/:event_id/edit
  #
  # Formulář na úpravu akce
  #
  # *Params*
  # event_id:: akce, kterou upravujeme
  #
  # *Provides*
  # @event:: akce, kterou upravujeme
  #
  def edit
    @breadcrumb = []
    @breadcrumb.push [ _breadcrumb_events ]
    @event_tab = 'edit'

    return unless _find_event(params[:event_id])

    @breadcrumb.push [ _breadcrumb_event_category(@event.event_category) ]
    @breadcrumb.push [ _breadcrumb_event(@event) ]
    @breadcrumb.push [ _breadcrumb_event_edit(@event) ]
    @paper_templates = _list_paper_templates
  end

  ##
  #  GET /act/events/:event_id/edit_participants
  #
  # Formulář na úpravu účastníků dané akce
  #
  # *Params*
  # event_id:: akce, kterou upravujeme
  #
  # *Provides*
  # @event:: akce, kterou upravujeme
  # @participants_yes:: účastníci (nikoliv náhradníci), kteří jedou
  # @participants_maybe:: účastníci (nikoliv náhradníci), kteří si nejsou jistí
  # @participants_no:: účastníci (nikoliv náhradníci), kteří nejedou
  # @substitutes_yes:: náhradníci (nikoliv účastníci), kteří jedou
  # @substitutes_maybe:: náhradníci (nikoliv účastníci), kteří si nejsou jistí
  # @substitutes_no:: náhradníci (nikoliv účastníci), kteří nejedou
  # @edit_participants:: flag, že chceme účastnické přihlášky upravovat
  # *Render* :show
  #
  def edit_participants
    @breadcrumb = []
    @breadcrumb.push [ _breadcrumb_events ]
    @event_tab = 'edit-par'

    return unless _find_event(params[:event_id])

    return render 'permission_denied', :locals => { :desired => "editovat ostatní účastníky na " } unless can? :update, Act::EventParticipant

    _get_participants()
    _filter_orgs()
    _filter_parts()

    @breadcrumb.push [ _breadcrumb_event_category(@event.event_category) ]
    @breadcrumb.push [ _breadcrumb_event(@event) ]
    @breadcrumb.push [ _breadcrumb_event_edit_participants(@event) ]

    @num_p_yes = @event.num_signed("yes", false, true, true)

    @edit_participants = true
    #render :show
  end

  ##
  #  GET /act/events/:event_id/edit_invitations/(:chosen)/(:role)
  #
  # Formulář na úpravu pozvánek na danou akci
  #
  # *Params*
  # event_id:: akce, kterou upravujeme
  # chosen:: filtruj podle pozvaných účastníků vs náhradníků vs nepozvaných
  # role:: filtruj podle účastínků vs orgů
  #
  # *Provides*
  # @event:: akce, kterou upravujeme
  # @chosen:: filtruj podle pozvaných účastníků vs náhradníků vs nepozvaných
  # @role:: filtruj podle účastínků vs orgů
  # @participants:: vyfiltrované účastnické účty
  #
  def edit_invitations
    @breadcrumb = []
    @breadcrumb.push [ _breadcrumb_events ]
    @event_tab = 'edit-inv'

    return unless _find_event(params[:event_id])

    @chosen = params[:chosen].nil? ? "ev" : params[:chosen]
    @role = (params[:role].nil? or params[:role] == 'p' or ! current_user.admin?) ? "p" : "o"

    @participants = Act::Participant::find_by_invitation(@event, @chosen, @role)

    @breadcrumb.push [ _breadcrumb_event(@event) ]
    @breadcrumb.push [ _breadcrumb_event_edit_invitations(@event) ]

    if (can? :read, Act::EventInvitation) and !(can? :create, Act::EventInvitation)
      @editing = false
      render :edit_invitations
      return
    end

    return render 'permission_denied', :locals => { :desired => "zobrazovat ani editovat pozvánky na " } unless can? :read, Act::EventInvitation

    @editing = true
    render :edit_invitations
  end

  ##
  #  GET /act/events/:event_id/enroll_others/(:status)/(:chosen)/(:role)
  #
  # Formulář na přihlášní (přp. změny stavu přihlášení) nových účastníků na danou akci
  #
  # *Params*
  # event_id:: akce, kterou upravujeme
  # status:: filtruj podle toho, jestli daný účastník jede/neví/nejde/je nepřihlášený
  # chosen:: filtruj podle pozvaných účastníků vs náhradníků vs nepozvaných
  # role:: filtruj podle účastínků vs orgů
  #
  # *Provides*
  # @event:: akce, kterou upravujeme
  # @chosen:: filtruj podle pozvaných účastníků vs náhradníků vs nepozvaných
  # @role:: filtruj podle účastínků vs orgů
  # @chosen:: filtruj podle pozvaných účastníků vs náhradníků vs nepozvaných
  # @participants:: vyfiltrované účastnické účty
  #
  def enroll_others
    @breadcrumb = []
    @breadcrumb.push [ _breadcrumb_events ]
    return unless _find_event(params[:event_id])

    @event_tab = 'enroll'

    @breadcrumb.push [ _breadcrumb_event(@event) ]
    @breadcrumb.push [ _breadcrumb_event_enroll_others(@event) ]

    return render 'permission_denied', :locals => { :desired => "přihlašovat ostatní účastníky na " } unless can? :create_other, Act::EventParticipant

    @chosen = params[:chosen] || "ev"
    @role = params[:role] || "p"
    @status = params[:status] || "ev"

    @participants = Act::Participant::find_by_participation(@event, @status, @chosen, @role)

    render :enroll_others
  end

  ##
  #  PATCH /act/events/:event_id
  #
  # Uprav danou akci
  #
  # *Params*
  # event_id:: akce, kterou upravujeme
  # event_params parametry akce, kterou upravujeme
  #
  # *Provides*
  # @event:: akce, kterou upravujeme
  #
  # *Redirect* @event
  #
  def update
    return render 'permission_denied', :locals => { :desired => "editovat existující " } unless can? :create, Act::Event

    return unless _find_event(params[:event_id])

    if @event.update(event_params)
      add_success "Akce úspěšně změněna"
      redirect_to @event
    else
      render :edit, status: :unprocessable_entity
    end
  end

  ##
  #  POST /act/event/:event_id/delete
  #
  # Smaže akci
  #
  # *Params*
  # event_id:: id akce
  #
  # *Redirect* act_events_path
  def delete
    return render 'permission_denied', :locals => { :desired => "mazat existující " } unless can? :delete, Act::Event

    return unless _find_event(params[:event_id])
    @event.destroy

    add_success "Akce úspěšně smazána. Současně s ní byla smazána i všechna data jí přidružená"
    redirect_to act_events_path
  end

  ##
  #  POST /act/events/filter
  #
  # Pomocná funkce pro funkci filter
  #
  # *Params*
  # event_category:: typ akce
  # enroll_status:: jakým způsobem tam jsem přihlášený
  #
  # *Redirect* act_events_filter_path
  def filter
    redirect_to act_events_filter_path(params[:event_category], params[:enroll_status])
  end

  ##
  #  GET /act/events/:event_id/display_participants
  #
  # Způsob hromadného zobrazení účastníků spolu s některými jejich informacemi
  #
  # *Params*
  # event_id:: akce, kterou upravujeme
  # filter_hasehs[]:: které informace chceme uživateli zobrazit
  #
  # *Provides*
  # @event:: akce, kterou upravujeme
  # @parts_yes:: účastníci (nikoliv náhradníci), kteří jedou
  # @parts_maybe:: účastníci (nikoliv náhradníci), kteří si nejsou jistí
  # @parts_no:: účastníci (nikoliv náhradníci), kteří nejedou
  # @substitutes_yes:: náhradníci (nikoliv účastníci), kteří jedou
  # @substitutes_maybe:: náhradníci (nikoliv účastníci), kteří si nejsou jistí
  # @substitutes_no:: náhradníci (nikoliv účastníci), kteří nejedou
  # @orgs_yes:: orgové, kteří jedou
  # @orgs_maybe:: orgové, kteří si nejsou jistí
  # @orgs_no:: orgové, kteří nejedou
  # @filter_hasehs[]:: které informace chceme uživateli zobrazit
  #
  ##
  # GET /act/events/:event_id/history
  #
  # Historie účastníků: tabulka lidí přihlášených na tuto akci (účastníci
  # i orgové/vedoucí) × ostatní akce, na kterých kdo z nich byl.
  #
  # *Provides*
  # *Params*
  # all:: '1' = všechny akce; jinak jen akce ze stejné skupiny
  #       (dlouhodobé/krátkodobé, viz Act::Event#long_term?)
  #
  # *Provides*
  # @history_people:: pole Act::Participant (orgové první, pak dle ročníku,
  #                   data narození a příjmení)
  # @history_events:: pole Act::Event, na kterých byl aspoň jeden z nich
  #                   (bez této akce), nejnovější vlevo (řazeno dle data
  #                   sestupně)
  # @history_att:: { [participant_id, event_id] => Act::EventParticipant }
  # @history_all:: bool — filtr na skupinu vypnut
  def history
    @breadcrumb = []
    @breadcrumb.push [ _breadcrumb_events ]
    @event_tab = 'history'

    return unless _find_event(params[:event_id])
    return render 'permission_denied', :locals => { :desired => "vidět historii účastníků na " } unless can? :read, Act::EventParticipant

    here = Act::EventParticipant.where(event_id: @event.id, status: 'yes', chosen: 'participant')
                                .includes(participant: :user)
    @history_people = here.map(&:participant).compact.uniq
                          .sort_by { |p| [p.org? ? 0 : 1,
                                          p.grade || 999,
                                          p.birth || Time.utc(9999),
                                          p.last_name.to_s.downcase, p.name.to_s.downcase] }

    others = Act::EventParticipant.where(participant_id: @history_people.map(&:id),
                                         status: 'yes', chosen: 'participant')
                                  .where.not(event_id: @event.id)
                                  .includes(:event, participant: :user)
    @history_all = params[:all] == '1'
    @history_events = others.map(&:event).compact.uniq
                            .sort_by { |e| [e.event_start || Date.new(1970), e.id] }
                            .reverse
    unless @history_all
      # default: jen akce ze stejné skupiny (dlouhodobé/krátkodobé)
      @history_events = @history_events.select { |e| e.long_term? == @event.long_term? }
    end
    @history_att = {}
    others.each { |ep| @history_att[[ep.participant_id, ep.event_id]] = ep }

    @breadcrumb.push [ _breadcrumb_event_category(@event.event_category) ]
    @breadcrumb.push [ _breadcrumb_event(@event) ]
  end

  def display_participants
    @breadcrumb = []
    format = params[:fmt]
    @event_tab = 'list'
    @wide_display = true
    @breadcrumb.push [ _breadcrumb_events ]

    return unless _find_event(params[:event_id])

    @breadcrumb.push [ _breadcrumb_event_category(@event.event_category) ]
    @breadcrumb.push [ _breadcrumb_event(@event) ]
    @breadcrumb.push [ _breadcrumb_event_display_participants(@event) ]

    return render 'not_allowed_to_show_others' unless can? :read_other, Act::Participant

    _get_participants()

    _filter_orgs()
    _filter_parts()

    @attr_table = Act::Participant::ATTR_TABLE
    @attr_table = @attr_table.merge(event_tshirt: "Velikost trička") if @event.spec_tshirt
    return _display_participants_render_table(format) if format =~ /^(csv|pdf|pdfl)$/


  end

  # vyfiltruje jen ty prvky pole arr, kde je v mask true
  def _mask(arr, mask)
    arr.each_with_index.select do |_,idx|
      mask[idx]
    end.map(&:first)
  end

  def _display_participants_render_table(format)
    col = params[:col] || '1111111111111111111111111111111111111111'
    mask = col.split(//).map { |x| x == '1' ? true : false }

    header = _mask(@attr_table.keys.map(&:to_s), mask)
    parts = []
    if params[:org] != '0'
      parts.push(@orgs_yes)   if params['yes'] != '0'
      parts.push(@orgs_maybe) if params['maybe'] != '0'
      parts.push(@orgs_no)    if params['no'] != '0'
    end
    if params[:par] != '0'
      parts.push(@parts_yes)   if params['yes'] != '0'
      parts.push(@parts_maybe) if params['maybe'] != '0'
      parts.push(@parts_no)    if params['no'] != '0'
    end
    if params[:sub] != '0'
      parts.push(@substitutes_yes)   if params['yes'] != '0'
      parts.push(@substitutes_maybe) if params['maybe'] != '0'
      parts.push(@substitutes_no)    if params['no'] != '0'
    end

    rows = []
    rows << header
    parts.each do |part|
      part.each do |event_participant|
        arr = @attr_table.keys.map { |attr| event_participant.display_attr(attr) }
        rows << _mask(arr, mask)
      end
    end

    if format == 'csv'
      csv_data = CSV.generate(col_sep: ",") do |csv|
        rows.each { |r| csv << r }
      end

      return send_data csv_data,
        filename: "list.csv",
        type: "text/csv; charset=utf-8",
        #type: "text/plain; charset=utf-8",
        disposition: "attachment"
    end

    if format == 'pdf' || format == 'pdfl'
      page_layout =  format == 'pdf'  ? :portrait :  :landscape
      Prawn::Document.generate("tabulka.pdf", page_layout: page_layout) do |pdf|
        #pdf.font_size 4
        #Rails.logger.info("rows=#{rows}")
        pdf.font_families.update(
          'andulka' => {
            normal: '/home/www/rails/tep/public/stylesheets/andulka/andulkabook-webfont.ttf',
          }
        )
        pdf.font('andulka')
        pdf.table(rows)
        send_data pdf.render,
          filename: "list.pdf",
          type: "application/pdf",
          disposition: "inline" # nebo "attachment"
      end
    end
  end
  ##
  #  POST /act/events/jakna
  #
  # Ukáže uživatelskou dokumentaci k akcím
  #
  #
  def jakna
    @breadcrumb = []
    @breadcrumb.push [ _breadcrumb_events ]
    @breadcrumb.push [ _breadcrumb_events_jakna ]

    @besidka = Act::Event.new(event_start: "Tue, 02 Jan 2024", event_end: "Tue, 02 Jan 2024", event_category: "be", title: "Besídka 2023",
    body: "", visible: "ev", activation_needed: "light",
    bonz_org: "antonin.hejny@gmail.com", event_info_url: "https://pikomat.mff.cuni.cz/setkani/besidka2023", spec_mass: false, bonz_parent: true,
    spec_participant: true)
    @sous = Act::Event.new(event_start: "Tue, 02 Jan 2024", event_end: "Tue, 10 Jan 2024", event_category: "so", title: "Jarní sous 2023",
    body: "", visible: "ev", activation_needed: "full",
    bonz_org: "antonin.hejny@gmail.com", event_info_url: "https://pikomat.mff.cuni.cz/soustredeni/2023/", spec_mass: true, bonz_parent: true,
    spec_participant: true, spec_place: true, spec_place_detail: "Praha,Brno,Ostrava",
    enable_only_specific_participants: true, enable_only_specific_substitutes: true, limit_num_participants: true, max_participants: 22)
  end

  ##
  #  GET /act/events/:event_id/papers_please/me
  #
  # pouze pro uzivatele, vraci pouze jeho papiry
  #
  #
  def my_papers_please
    papers_please
  end

  ##
  #  GET /act/events/:event_id/papers_please/:participant_id
  #
  # Vratí pdf s předvyplněnýma hodnotama
  #
  #
  def papers_please
     event_id = params[:event_id]
     participant_id = params[:participant_id]
     participant = if ! participant_id.nil?
        Act::Participant.find_by(id: participant_id)
     elsif ! current_user.nil?
        current_user.participant
     end

     event = Act::Event.find_by(id: event_id)

     if event.paper_template.empty?
       return render plain: "tento event nema papiry (ev#{event.id})" if participant.nil?
       return render plain: "tento event nema papiry (ev#{event.id} par#{participant.id})"
     end

     date_today = Time.now.strftime('%-d. %-m. %-Y')

     event_category = event.get_event_category

     stash = {
       event_name: event.title,
       event_date: event.date_str,
       event_category_name: event_category.name,
       event_category_short: event_category.name,
       event_category_short_genitiv: event_category.genitiv,
       event_category_name_genitiv: event_category.genitiv,
       event_info_url: event.event_info_url,
       event_medic: event.event_medic,
       #event_spec_place_return: event.spec_place_return_detail,
       exit_place: event.spec_place_return_detail,
       date_today: date_today,
     }
     if ! participant.nil?
       participiant_birth_date =  participant.birth.strftime('%-d. %-m. %-Y')
       place = participant.address_lokativ || "V Praze"
       stash.merge!( {
         place: place,
         name: participant.name,
         full_name: "#{participant.name} #{participant.last_name}",
         last_name: participant.last_name,
         address: participant.address,
         adress: participant.address,
         birth_date: participiant_birth_date,
         nickname: participant.nickname,
         email: participant.email,
         parent_email: participant.parent_email,
         parent_phone: participant.parent_phone,
         phone: participant.phone,
         health_insurance: participant.health_insurance,
         rc: participant.birth_number,
         sex: participant.sex,
         a: participant.sex == 'male' ? '' : 'a',
       })
     end

     stash.keys.each do |key|
       (1..5).each do |i|
         stash["#{key}+#{i}"] =  stash[key]
       end
     end

     stash[:stash] = JSON.pretty_generate(stash)

     template_path = "#{Rails.root.to_s}/#{PAPER_TEMPLATES_DIR}/#{event.paper_template}"
     return render plain: "template file does not exist" unless File.exist?(template_path)

     Tempfile.create(['filled_pdf', '.pdf']) do |tempfile|
       pdftk = PdfForms.new( data_format: 'XFdf')
       pdftk.fill_form template_path, tempfile.path, stash, flatten:false, need_appearances: true
       pdf_data = File.binread(tempfile.path)
       send_data pdf_data, filename: "papers.pdf", type: "application/pdf", disposition: "inline"
     end
  end

  private
    def event_params
      params.require(:event).permit!
    end

    def event_participant_params
      ep = params.require(:event_participant).permit!#(:event_id, :participant_id, :status, :note, :place, :mass, :participant_info)
      ep[:tshirt] = '' if params.key?(:want_tshirt) && params[:want_tshirt] != '1'
      ep
    end

    def _find_event(event_id)
      @event = Act::Event.find_by(id: event_id)
      if @event.nil?
        render :not_found
        return false
      end

      if @event.event_visible?(current_user)
        return true
      else
        render :not_allowed_to_show
        return false
      end
    end

    def _send_bonz_org(bonz_email, event_participant, is_new)
      # mail h-orgovi akce

      if bonz_email != ""
        new_txt = is_new ? "Přihlášení " : "Změna přihlášky "

        if event_participant.org?
          person_txt = event_participant.male? ? "orga " : "orgyně "
        else
          person_txt = event_participant.male? ? "účastníka " : "účastnice "
        end

        name_txt = event_participant.participant.name + " " + event_participant.participant.last_name + " "

        event_txt = "na akci " + event_participant.event.title + " "

        Act::Mailer.event_bonz_org(bonz_email, 'PIKOMAT: ' + new_txt + person_txt + name_txt + event_txt, event_participant, is_new).deliver_later
      end
    end

    def _send_bonz_parent(bonz_email, event_participant, is_new)
      # mail rodici ucastnika
      if bonz_email and bonz_email != ""
        new_txt = is_new ? "Přihlášení " : "Změna přihlášky "
        gender_txt = event_participant.male? ? "Vašeho syna " : "Vaší dcery "
        Act::Mailer.event_bonz_parent(bonz_email, 'PIKOMAT: ' + new_txt + gender_txt + " na akci", event_participant, is_new).deliver_later
      end
    end

    def _get_participants()
      @participants_all = Act::EventParticipant.where(event_id: @event.id)

      @participants_yes = Act::EventParticipant.where(event_id: @event.id).where(status: "yes").where(chosen: "participant").order(place: :asc, created_at: :asc)
      @participants_maybe = Act::EventParticipant.where(event_id: @event.id).where(status: "maybe").where(chosen: "participant").order(place: :asc, created_at: :asc)
      @participants_no = Act::EventParticipant.where(event_id: @event.id).where(status: "no").where(chosen: "participant").order(place: :asc, created_at: :asc)

      @substitutes_yes = Act::EventParticipant.where(event_id: @event.id).where(status: "yes").where(chosen: "substitute").order(place: :asc, created_at: :asc)
      @substitutes_maybe = Act::EventParticipant.where(event_id: @event.id).where(status: "maybe").where(chosen: "substitute").order(place: :asc, created_at: :asc)
      @substitutes_no = Act::EventParticipant.where(event_id: @event.id).where(status: "no").where(chosen: "substitute").order(place: :asc, created_at: :asc)
    end

    def _filter_orgs()
      @orgs_yes = @participants_yes.select{ |p| p.participant.org? }
      @orgs_maybe = @participants_maybe.select{ |p| p.participant.org? }
      @orgs_no = @participants_no.select{ |p| p.participant.org? }
    end

    def _filter_parts()
      @parts_yes = @participants_yes.select{ |p| ! p.participant.org? }
      @parts_maybe = @participants_maybe.select{ |p| ! p.participant.org? }
      @parts_no = @participants_no.select{ |p| ! p.participant.org? }
    end

    def _breadcrumb_events()
      return {
        name: "Akce",
        ico: "fa-bullhorn",
        url: act_events_path
      }
    end

    def _breadcrumb_event_category(event_category)
      category = Act::EventCategory.find_by(code: event_category)
      category_name = category.nil? ? '?' : category.name
      return {
        name: category_name,
        url: act_events_filter_path(event_category, :all),
      }
    end

    def _breadcrumb_event(event)
      return {
        name: event.title,
        url: act_event_path(event)
      }
    end

    def _breadcrumb_event_new
      return {
        name: "Nová akce",
        url: act_event_new_path
      }
    end

    def _breadcrumb_event_edit(event)
      return {
        name: "Edit",
        url: act_event_edit_path(event)
      }
    end

    def _breadcrumb_event_edit_participants(event)
      return {
        name: "Editace účastníků",
        url: act_event_edit_participants_path(event)
      }
    end

    def _breadcrumb_event_edit_invitations(event)
      return {
        name: "Editace pozvánek",
        url: act_event_edit_invitations_path(event)
      }
    end

    def _breadcrumb_event_enroll_others(event)
      return {
        name: "Přihlašování ostatních",
        url: act_event_enroll_others_path(event)
      }
    end

    def _breadcrumb_event_display_participants(event)
      return {
        name: "Účastníci",
        url: act_event_display_participants_path(event)
      }
    end

    def _breadcrumb_events_jakna
      return {
        name: "Jakna",
        url: act_events_jakna_path
      }
    end
    def _list_paper_templates
      Dir.glob("#{Rails.root.to_s}/#{PAPER_TEMPLATES_DIR}/*.pdf").map do |file|
        File.basename(file)
      end.prepend(["None", ''])
    end
end
