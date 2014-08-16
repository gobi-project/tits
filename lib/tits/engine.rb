# Thinning System. Thins out the data sets stored in the database over time.
module ThinningSystem

  # Rails Engine for autoloading required files in file tree
  class Engine < ::Rails::Engine
    config.autoload_paths += Dir["#{config.root}/lib/**/"]
  end

end
