require 'nsconfig'

module Alerter
    extend NSConfig

    def self.preconfig base_path
        Alerter.config_path = File.join(base_path,'config')
        if Alerter.get_environment == 'development'
            Alerter[:datamapper_parameters] = File.join(base_path,Alerter[:datamapper_parameters])
        end
    end

    def self.dm_setup
        require 'data_mapper'
        require Alerter[:datamapper_require]
        DataMapper.setup(:default, "#{Alerter[:datamapper_adapter]}://#{Alerter[:datamapper_parameters]}")
        DataMapper::Model.raise_on_save_failure = true
        require 'alerter/models'
    end
end
