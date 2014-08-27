# encoding: utf-8
Tep::Application.routes.draw do

  devise_for :users


  get  '/csrf.json'                   => 'tep#csrf',             :as => :tep_csrf
  # přidání akcí je třeba přidat i práva v app/models/ability.rb
  # anon:
  get  '/sosna/solver/new'                   => 'sosna/solver#new',             :as => :sosna_solver_new
  post '/sosna/solver/create'                => 'sosna/solver#create',          :as => :sosna_solver_anon_create
  get  '/sosna/solver/tnx'                   => 'sosna/solver#create_tnx',      :as => :sosna_solver_create_tnx

  # user:
  get  '/sosna/solutions/user(/:roc(/:se))'  => 'sosna/solution#user_index',    :as => :sosna_solutions_user
  patch '/sosna/solution/upload'             => 'sosna/solution#upload',        :as => :sosna_solution_upload
  post '/sosna/solution/upload_rev'         => 'sosna/solution#upload_rev',   :as => :sosna_solution_upload_rev
  get  '/sosna/solution/:id/down'            => 'sosna/solution#download',      :as => :sosna_solution_download
  get  '/sosna/solution/:id/down_rev'       => 'sosna/solution#download_rev', :as => :sosna_solution_download_rev
  #get  '/sosna/solution/:id/down(/:ori)'     => 'sosna/solution#download',      :as => :sosna_solution_download
  #get  '/sosna/solution/:id/down_rev(/:ori)'=> 'sosna/solution#download_rev', :as => :sosna_solution_download_rev

  # org:
  get  '/sosna/solutions/:roc/:se/edit'      => 'sosna/solution#edit',          :as => :sosna_solutions_edit2
  get  '/sosna/solutions/:roc/:se/:ul/edit'  => 'sosna/solution#edit',          :as => :sosna_solutions_edit
  get  '/sosna/solutions(/:roc(/:se(/:ul)))' => 'sosna/solution#index',         :as => :sosna_solutions_org
  post '/sosna/solutions/update_scores'      => 'sosna/solution#update_scores', :as => :sosna_solutions_update_scores
  post '/sosna/solutions/update_papers'      => 'sosna/solution#update_papers', :as => :sosna_solutions_update_papers
  post '/sosna/solutions/update_penalisations'=>'sosna/solution#update_penalisations', :as => :sosna_solutions_update_penalisations
  post '/sosna/solution/update'              => 'sosna/solution#update',        :as => :sosna_solution_update
  post '/sosna/solution/update_results'      => 'sosna/solution#update_results',:as => :sosna_solution_update_results
  get  '/sosna/solution/downall'             => 'sosna/solution#downall',       :as => :sosna_solution_down

  get  '/sosna/problems'                     => 'sosna/problem#index',          :as => :sosna_problems
  get  '/sosna/problem(/:id)'                => 'sosna/problem#show',           :as => :sosna_problem
  patch '/sosna/problem/update'              => 'sosna/problem#update',         :as => :sosna_problem_update
  post '/sosna/problem/update'               => 'sosna/problem#update',         :as => :sosna_problem_updateP
  post '/sosna/problem/new_round'            => 'sosna/problem#new_round',      :as => :sosna_problem_new_round
  post '/sosna/problem/:id/delete'           => 'sosna/problem#delete',         :as => :sosna_problem_delete

  get  '/sosna/solvers(/:annual)'             => 'sosna/solver#index',           :as => :sosna_solvers
  #get  '/sosna/solvers'                      => 'sosna/solver#index',           :as => :sosna_solvers
  get  '/sosna/solver(/:id)'                 => 'sosna/solver#show',            :as => :sosna_solver
  patch '/sosna/solver/update'               => 'sosna/solver#update',          :as => :sosna_solver_update
  post '/sosna/solver/:id/delete'            => 'sosna/solver#delete',          :as => :sosna_solver_delete

  get  '/sosna/schools'                      => 'sosna/school#index',           :as => :sosna_schools
  get  '/sosna/school/new'                   => 'sosna/school#new',             :as => :sosna_school_new
  get  '/sosna/school/:id/show'              => 'sosna/school#show',            :as => :sosna_school
  patch '/sosna/school/update'               => 'sosna/school#update',          :as => :sosna_school_update
  post  '/sosna/school/update'               => 'sosna/school#update',          :as => :sosna_school_updateP
  post '/sosna/school/:id/delete'            => 'sosna/school#delete',          :as => :sosna_school_delete

  get  '/sosna/config'                       => 'sosna/config#index',           :as => :sosna_configs
  post '/sosna/config/update'                => 'sosna/config#update',          :as => :sosna_config_update

  # tep
  get  '/users'                              => 'tep#users',                    :as => :users_list
  get  '/user/:id/show'                      => 'tep#user',                     :as => :user_show
  patch '/user/:id/update'                   => 'tep#user_update',              :as => :user_update
  post  '/user/:id/delete'                   => 'tep#user_delete',              :as => :user_delete
  patch '/user/:id/role'                     => 'tep#user_role_change',         :as => :user_role_change
  post  '/user/:id/action/:what'             => 'tep#user_action',              :as => :user_action
  get  '/reg/:token'                         => 'tep#user_finish_registration', :as => :user_finish_registration


  get  '/faq'                                => "tep#faq",                      :as => :faq

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

