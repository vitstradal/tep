# encoding: utf-8
Tep::Application.routes.draw do

  use_doorkeeper
  # use_doorkeeper_openid_connect
  devise_for :users


  # přidání akcí je třeba přidat i práva v app/models/ability.rb
  # anon:
  get  '/sosna/solver/new'                   => 'sosna/solver#new',                     :as => :sosna_solver_new
  get  '/prihlaska'                          => 'sosna/solver#new',                     :as => :sosna_solver_new_short
#  get  '/bonus/new'                          => 'sosna/solver#new_bonus',               :as => :sosna_solver_new_bonus
  get  '/pikomaso'                           => 'sosna/solver#new_bonus',               :as => :sosna_solver_new_bonus
  get  '/sosna/solver/confirm'               => 'sosna/solver#user_solver_confirm',     :as => :sosna_solver_user_solver_confirm
  post '/sosna/solver/create'                => 'sosna/solver#create',                  :as => :sosna_solver_anon_create
  get  '/sosna/solver/tnx'                   => 'sosna/solver#create_tnx',              :as => :sosna_solver_create_tnx
  post '/sosna/solver/confirm_none_to_next'  => 'sosna/solver#confirm_none_to_next',    :as => :sosna_solver_confirm_none_to_next
  get  '/sosna/solver/spam'                  => 'sosna/solver#spam',                    :as => :sosna_solver_spam 
  post '/sosna/solver/spam'                  => 'sosna/solver#do_spam',                 :as => :sosna_solver_do_spam
#  post '/sosna/solver/delete_zero_solvers'   => 'sosna/solver#delete_zero_solvers',     :as => :sosna_solver_delete_zero_solvers

  get   '/inform/index/(:form)'                 => 'inform#index',            :as => :inform_index
  post  '/inform/add'                        => 'inform#add',              :as => :inform_add
  get   '/inform/add'                        => 'inform#add',              :as => :inform_add_get
  get   '/inform/tnx'                        => 'inform#tnx',              :as => :inform_tnx
  post   '/inform/del/:id'                        => 'inform#del',              :as => :inform_del
  post   '/inform/delfrom/:form'                        => 'inform#delform',              :as => :inform_delform

  # user:
  get  '/sosna/solutions/user/jr'                 => 'sosna/solution#user_index_junior', :as => :sosna_solutions_user_junior
  get  '/sosna/solutions/user(/:roc(/:level(/:se(/:id))))' => 'sosna/solution#user_index', :as => :sosna_solutions_user
  get  '/sosna/solutions/bonus'                   => 'sosna/solution#user_bonus',    :as => :sosna_solutions_user_bonus
  patch '/sosna/solution/upload'                  => 'sosna/solution#upload',        :as => :sosna_solution_upload
  post '/sosna/solution/upload_rev'               => 'sosna/solution#upload_rev',   :as => :sosna_solution_upload_rev
  post  '/sosna/solutions/upload_confirm'         => 'sosna/solution#upload_confirm_file',    :as => :sosna_solutions_upload_confirm_file
  get  '/sosna/solutions/confirm_file'            => 'sosna/solution#get_confirm_file',    :as => :sosna_solutions_get_confirm_file
  get  '/sosna/solution/confirm_files'            => 'sosna/solution#get_confirm_files',    :as => :sosna_solutions_get_confirm_files
  get  '/sosna/solution/:id/down'                 => 'sosna/solution#download',      :as => :sosna_solution_download

  get  '/sosna/solver/aesop'                             => 'sosna/solver#aesop',            :as => :sosna_solver_aesop
  get  '/sosna/solver/aesop/index'                       => 'sosna/solver#aesop_index',      :as => :sosna_solver_aesop_index
  get  '/sosna/solver/aesop/:roc'                        => 'sosna/solver#aesop_annual',     :as => :sosna_solver_aesop_annual
  post '/sosna/solver/aesop/create'                      => 'sosna/solver#aesop_create',     :as => :sosna_solver_aesop_create
  post '/sosna/solver/aesop/refres-index'                => 'sosna/solver#aesop_refresh_index',     :as => :sosna_solver_aesop_refres_index


  get  '/sosna/solution/:id/down_rev'       => 'sosna/solution#download_rev', :as => :sosna_solution_download_rev
  #get  '/sosna/solution/:id/down(/:ori)'     => 'sosna/solution#download',      :as => :sosna_solution_download
  #get  '/sosna/solution/:id/down_rev(/:ori)'=> 'sosna/solution#download_rev', :as => :sosna_solution_download_rev

  # participants:
  get   '/act/participants/new_year'                               => 'act/participants#new_year',           :as => :act_participants_new_year
  get   '/act/participants/previous_year'                          => 'act/participants#previous_year',      :as => :act_participants_previous_year
  post  '/act/participants/create_other'                           => 'act/participants#create_other',       :as => :act_participant_create_other
  get   '/act/participants/filter/:grade/:role'                    => 'act/participants#index',              :as => :act_participant_filter

  get   '/act/participants'                                        => 'act/participants#index',              :as => :act_participants
  get   '/act/participants/new'                                    => 'act/participants#new',                :as => :act_participant_new
  get   '/act/participants/new_complet'                            => 'act/participants#new_complet',        :as => :act_participant_new_complet
  post  '/act/participants'                                        => 'act/participants#create'
  post  '/act/participants/create_complet'                         => 'act/participants#create_complet',     :as => :act_participant_create_complet
  get   '/act/participants/:participant_id'                        => 'act/participants#show',               :as => :act_participant
  get   '/act/participants/:participant_id/edit'                   => 'act/participants#edit',               :as => :act_participant_edit
  patch '/act/participants/:participant_id'                        => 'act/participants#update',             :as => :act_participant_update
  post  '/act/participants/:participant_id/confirm_delete'         => 'act/participants#confirm_delete',     :as => :act_participant_confirm_delete
  post  '/act/participants/:participant_id/delete'                 => 'act/participants#delete',             :as => :act_participant_delete
  get   '/act/participant/tnx'                                     => 'act/participants#create_tnx',         :as => :act_participant_create_tnx

  # event_categories:
  get   '/act/event_categories'                                    => 'act/event_categories#index',          :as => :act_event_categories
  get   '/act/event_categories/jakna'                              => 'act/event_categories#jakna',          :as => :act_event_categories_jakna
  get   '/act/event_categories/new'                                => 'act/event_categories#new',            :as => :act_event_category_new
  post  '/act/event_categories'                                    => 'act/event_categories#create'
  get   '/act/event_categories/:code'                              => 'act/event_categories#show',           :as => :act_event_category
  get   '/act/event_categories/:code/edit'                         => 'act/event_categories#edit',           :as => :act_event_category_edit
  patch '/act/event_categories/:code'                              => 'act/event_categories#update'
  post  '/act/event_categories/:code/delete'                       => 'act/event_categories#delete',         :as => :act_event_category_delete

  # events
  get '/act/events'                                                => 'act/events#index',                    :as => :act_events
  get '/act/events/new'                                            => 'act/events#new',                      :as => :act_event_new
  post '/act/events/create'                                        => 'act/events#create',                   :as => :act_event_create
  post '/act/events/filter'                                        => 'act/events#filter',                   :as => :act_events_filter_helper
  get  '/act/event/jakna'                                          => 'act/events#jakna',                    :as => :act_events_jakna
  get '/act/events/filter/:event_category/:enroll_status'          => 'act/events#index',                    :as => :act_events_filter
  get '/act/events/:event_id'                                      => 'act/events#show',                     :as => :act_event
  patch '/act/events/:event_id'                                    => 'act/events#update',                   :as => :act_event_update
  get '/act/events/:event_id/edit'                                 => 'act/events#edit',                     :as => :act_event_edit
  post '/act/events/:event_id/delete'                              => 'act/events#delete',                   :as => :act_event_delete
  post '/act/events/:event_id/enroll'                              => 'act/events#enroll',                   :as => :act_event_enroll
  post '/act/events/:event_id/enroll_other'                        => 'act/event_participants#enroll_other', :as => :act_event_enroll_other
  get '/act/events/:event_id/edit_participants'                    => 'act/events#edit_participants',        :as => :act_event_edit_participants
  get '/act/events/:event_id/edit_invitations/(:chosen)/(:role)'   => 'act/events#edit_invitations',         :as => :act_event_edit_invitations
  get '/act/events/:event_id/enroll_others/(:status)/(:chosen)/(:role)' => 'act/events#enroll_others',       :as => :act_event_enroll_others
  post '/act/events/:event_id/participants/:participant_id/update' => 'act/event_participants#update',       :as => :act_event_update_participant
  post '/act/events/:event_id/participants/:participant_id/delete' => 'act/event_participants#delete',       :as => :act_event_delete_participant
  post '/act/events/:event_id/participants/:participant_id/choose' => 'act/event_participants#choose',       :as => :act_event_participant_choose
  get '/act/events/:event_id/display_participants'                 => 'act/events#display_participants',     :as => :act_event_display_participants

  # event_invitations
  post '/act/event_invitations/:event_id/:participant_id/save'     => 'act/event_invitations#save',          :as => :act_event_save_invitation

  # org:
  get  '/sosna/solutions/lidi(/:roc(/:level(/:se(/:ul))))' => 'sosna/solution#lidi',           :as => :sosna_solutions_lidi
  get  '/sosna/solutions/rocnik(/:roc)'         => 'sosna/solution#rocnik',           :as => :sosna_solutions_rocnik
  get  '/sosna/solutions/vysl(/:roc(/:level(/:se(/:ul))))'     => 'sosna/solution#vysl_pik', :as => :sosna_solutions_vysl_pik
  get  '/sosna/solutions/vyslwiki(/:roc(/:level(/:se(/:ul))))' => 'sosna/solution#vysl_wiki',:as => :sosna_solutions_vysl_wiki

  get  '/sosna/solutions/:roc/:level/:se/edit'      => 'sosna/solution#edit',          :as => :sosna_solutions_edit2
  get  '/sosna/solutions/:roc/:level/:se/:ul/edit'  => 'sosna/solution#edit',          :as => :sosna_solutions_edit

  get  '/sosna/solutions(/:roc(/:level(/:se(/:ul))))' => 'sosna/solution#index',     :as => :sosna_solutions_org

  post '/sosna/solution/update_results'      => 'sosna/solution#update_results',:as => :sosna_solution_update_results
  post '/sosna/solutions/update_scores'      => 'sosna/solution#update_scores', :as => :sosna_solutions_update_scores
  post '/sosna/solutions/update_papers'      => 'sosna/solution#update_papers', :as => :sosna_solutions_update_papers
  post '/sosna/solutions/update_penalisations' => 'sosna/solution#update_penalisations', :as => :sosna_solutions_update_penalisations
  #post '/sosna/solution/update'              => 'sosna/solution#update',        :as => :sosna_solution_update
  get  '/sosna/solution/downall'             => 'sosna/solution#downall',       :as => :sosna_solution_down_all

  post  '/sosna/solution/:id/resing'         => 'sosna/solution#resign',      :as => :sosna_solution_resign
  post  '/sosna/solution/:id/nosign'         => 'sosna/solution#nosign',      :as => :sosna_solution_nosign

  get  '/sosna/problems'                     => 'sosna/problem#index',          :as => :sosna_problems
  get  '/sosna/problem(/:id)'                => 'sosna/problem#show',           :as => :sosna_problem
  patch '/sosna/problem/update'              => 'sosna/problem#update',         :as => :sosna_problem_update
  post '/sosna/problem/update'               => 'sosna/problem#update',         :as => :sosna_problem_updateP
  post '/sosna/problem/new_round'            => 'sosna/problem#new_round',      :as => :sosna_problem_new_round
  post '/sosna/problem/:id/delete'           => 'sosna/problem#delete',         :as => :sosna_problem_delete

  post  '/sosna/solvers/labels'               => 'sosna/solver#labels',         :as => :sosna_solver_labels_post
  get  '/sosna/solvers/labels'                => 'sosna/solver#labels',         :as => :sosna_solver_labels
  post  '/sosna/solver/:id/dup(/:roc)'        => 'sosna/solver#dup', :as => :sosna_solver_dup
  get  '/sosna/solvers/tep_emails(/:roc)'     => 'sosna/solver#tep_emails',         :as => :sosna_solver_tep_emails
  get  '/sosna/solvers/list(/:roc)'           => 'sosna/solver#index',           :as => :sosna_solvers
  #get  '/sosna/solvers'                      => 'sosna/solver#index',           :as => :sosna_solvers
  get  '/sosna/solver(/:id)'                 => 'sosna/solver#show',            :as => :sosna_solver
  patch '/sosna/solver/update'               => 'sosna/solver#update',          :as => :sosna_solver_update
  post '/sosna/solver/update_confirm'        => 'sosna/solver#update_confirm',  :as => :sosna_solver_update_confirm
  post '/sosna/solver/:id/delete'            => 'sosna/solver#delete',          :as => :sosna_solver_delete

  get  '/sosna/schools'                      => 'sosna/school#index',           :as => :sosna_schools
  get  '/sosna/school/new'                   => 'sosna/school#new',             :as => :sosna_school_new
  get  '/sosna/school/:id/show'              => 'sosna/school#show',            :as => :sosna_school
  patch '/sosna/school/update'               => 'sosna/school#update',          :as => :sosna_school_update
  post  '/sosna/school/update'               => 'sosna/school#update',          :as => :sosna_school_updateP
  post '/sosna/school/:id/delete'            => 'sosna/school#delete',          :as => :sosna_school_delete

  get  '/sosna/config(/:tab)'                => 'sosna/config#index',           :as => :sosna_configs
  post '/sosna/config/update'                => 'sosna/config#update',          :as => :sosna_config_update

  # tep
  get  '/access'                             => 'tep#access',                   :as => :access_denied
  get  '/users(/:role)'                      => 'tep#users',                    :as => :users_list
  post '/user/new'                           => 'tep#user_new',                 :as => :user_new
  get  '/user/:id/show(/:tab)'               => 'tep#user',                     :as => :user_show
  patch '/user/:id/update'                   => 'tep#user_update',              :as => :user_update
  post  '/user/:id/delete'                   => 'tep#user_delete',              :as => :user_delete
  patch '/user/:id/role'                     => 'tep#user_role_change',         :as => :user_role_change
  post  '/user/:id/action/:what'             => 'tep#user_action',              :as => :user_action
  get  '/reg/:token'                         => 'tep#user_finish_registration', :as => :user_finish_registration

  # post
  get    '/jabber/prebind'                   => 'jabber#prebind',               :as => :jabber_prebind
  patch  '/jabber/:id/update'                => 'jabber#update',                :as => :jabber_update
  post   '/jabber/:id/delete'                => 'jabber#delete',                :as => :jabber_delete
  post   '/jabber/new/:user_id'              => 'jabber#new',                   :as => :jabber_new

  post  '/jabber/auth'                       => 'jabber#auth',                  :as => :jabber_auth_post
  get   '/jabber/auth'                       => 'jabber#auth',                  :as => :jabber_auth

  get  '/die'                                => 'tep#die', :as => :tep_die


  get  '/faqold'                             => "tep#faq",                      :as => :faq
  #get  '/500'                                => "tep#error",                   :as => :error

  get  '/priklady/sklad'                      => "priklady#sklad",              :as => :priklady_sklad

  get  '/me/gitlab'                           => "credentials#me_gitlab",       :as => :credentials_me_gitlab
  get  '/me'                                  => "credentials#me",              :as => :credentials_me
  get  '/klepstatus'                          => "klep#status",                 :as => :klep_status
  get  '/tepna/info'                          => "tepna#info",                  :as => :tepna_info
  post '/tepna/debug'                         => "tepna#debug",                 :as => :tepna_debug


  Giwi.giwis.each_value do |giwi|
     next if giwi.name.to_s == 'main'
     url = giwi.url
     route_name = "wiki_#{giwi.name}".to_sym
     #print "wiki: #{route_name}\n"
     route_name_post = "wiki_#{giwi.name}_post".to_sym
     get  '/' + url + '(/*path)'       => 'giwi#show',      :as =>  route_name,      constrains: { path: /.*/ , wiki: giwi.name}, defaults: {wiki: giwi.name}
     post '/' + url + '(/*path)'       => 'giwi#update',    :as =>  route_name_post, constrains: { path: /.*/ , wiki: giwi.name}, defaults: {wiki: giwi.name}
  end
  giwi = Giwi.get_giwi('main')
  #print "main\n"
  if giwi
     url = giwi.url
     route_name = "wiki_#{giwi.name}".to_sym
     route_name_post = "wiki_#{giwi.name}_post".to_sym
     get  '/(*path)'       => 'giwi#show_root',      :as =>  route_name,      constrains: { path: /.*/ , wiki: giwi.name}, defaults: {wiki: giwi.name, path: 'index'}
     post '/(*path)'       => 'giwi#update_root',    :as =>  route_name_post, constrains: { path: /.*/ , wiki: giwi.name}, defaults: {wiki: giwi.name}
  end

  # You can have the root of your site routed with "root"
  # just remember to delete public/index.html.
  root :to => "giwi#show", :as => :root, defaults: {wiki: 'main', path: 'index'}
  #root :to => "tep#index", :as => :root

  # See how all your routes lay out with "rake routes"
end

