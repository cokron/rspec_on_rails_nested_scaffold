class RspecNestedScaffoldGenerator < Rails::Generator::NamedBase
  default_options :skip_migration => false

  attr_reader   :controller_name,
  :controller_class_path,
  :controller_file_path,
  :controller_class_nesting,
  :controller_class_nesting_depth,
  :controller_class_name,
  :controller_singular_name,
  :controller_plural_name,
  :resource_edit_path,
  :default_file_extension,
  :nesting_owner
  alias_method  :controller_file_name,  :controller_singular_name
  alias_method  :controller_table_name, :controller_plural_name

  def initialize(runtime_args, runtime_options = {})
    I18n.locale = "en-US"
    super
    raise "For #{$0} #{File.basename(__FILE__, '.rb')} you must specify the --owner option.  See --help" unless options[:owner]

    @nesting_owner = options[:owner].underscore.singularize

    @controller_name = @name.pluralize

    base_name, @controller_class_path, @controller_file_path, @controller_class_nesting, @controller_class_nesting_depth = extract_modules(@controller_name)
    @controller_class_name_without_nesting, @controller_singular_name, @controller_plural_name = inflect_names(base_name)

    if @controller_class_nesting.empty?
      @controller_class_name = @controller_class_name_without_nesting
    else
      @controller_class_name = "#{@controller_class_nesting}::#{@controller_class_name_without_nesting}"
    end

    @resource_generator = "scaffold"
    @default_file_extension = "html.erb"

    if ActionController::Base.respond_to?(:resource_action_separator)
      @resource_edit_path = "/edit"
    else
      @resource_edit_path = ";edit"
    end
  end

  def manifest
    record do |m|

      # Check for class naming collisions.
      m.class_collisions(controller_class_path, "#{controller_class_name}Controller", "#{controller_class_name}Helper")
      m.class_collisions(class_path, "#{class_name}")

      # Controller, helper, views, and spec directories.
      m.directory(File.join('app/models', class_path))
      m.directory(File.join('app/controllers', controller_class_path))
      m.directory(File.join('app/helpers', controller_class_path))
      m.directory(File.join('app/views', controller_class_path, controller_file_name))
      m.directory(File.join('spec/controllers', controller_class_path))
      m.directory(File.join('spec/models', class_path))
      m.directory(File.join('spec/helpers', class_path))
      m.directory File.join('spec/fixtures', class_path)
      m.directory File.join('spec/views', controller_class_path, controller_file_name)

      #Controller spec, class, and helper.
      m.template 'rspec_nested_scaffold:routing_spec.rb',
      File.join('spec/controllers', controller_class_path, "#{controller_file_name}_routing_spec.rb")

      m.template 'rspec_nested_scaffold:controller_spec.rb',
      File.join('spec/controllers', controller_class_path, "#{controller_file_name}_controller_spec.rb")

      m.template "rspec_nested_scaffold:controller.rb",
      File.join('app/controllers', controller_class_path, "#{controller_file_name}_controller.rb")

      #m.template 'rspec_scaffold:helper_spec.rb',
      #File.join('spec/helpers', class_path, "#{controller_file_name}_helper_spec.rb")

      # DO not generate helper BG 20081210
      #      m.template "#{@resource_generator}:helper.rb",
      #      File.join('app/helpers', controller_class_path, "#{controller_file_name}_helper.rb")

      for action in scaffold_views
        m.template(
                   "rspec_nested_scaffold:view_#{action}.#{@default_file_extension}",
                   File.join('app/views', controller_class_path, controller_file_name, "#{action}.#{default_file_extension}")
                   )
        unless action == '_form' || action == '_index_item'
          m.template "rspec_nested_scaffold:#{action}_erb_spec.rb",
          File.join('spec/views', controller_class_path, controller_file_name, "#{action}.#{default_file_extension}_spec.rb")
        end
      end

      # Model class, unit test, and fixtures.
      m.template 'model.rb',      File.join('app/models', class_path, "#{file_name}.rb")
      m.template 'model:fixtures.yml',  File.join('spec/fixtures', class_path, "#{table_name}.yml")
      m.template 'model_spec.rb',       File.join('spec/models', class_path, "#{file_name}_spec.rb")

      # View specs
      #      m.template 'rspec_nested_scaffold:view_form.html.erb',      File.join('app/views', controller_class_path, "_form.html.erb")

      unless options[:skip_migration]
        m.migration_template(
                             'model:migration.rb', 'db/migrate',
                             :assigns => {
                               :migration_name => "Create#{class_name.pluralize.gsub(/::/, '')}",
                               :attributes     => attributes
                             },
                             :migration_file_name => "create_#{file_path.gsub(/\//, '_').pluralize}"
                             )
      end

      m.route_resources controller_file_name

    end
  end

  protected

  # Override with your own usage banner.
  def banner
    "Usage: #{$0} #{File.basename(__FILE__, '.rb')} ModelName --owner=OwnerName field:type field:type"
  end

  def add_options!(opt)
    opt.separator ''
    opt.separator 'Options:'
    opt.on("--skip-migration",
           "Don't generate a migration file for this model") { |v| options[:skip_migration] = v }
    opt.on("--owner=owner", '-o', 'Nested resource owner') { |v| options[:owner] = v }
  end

  def scaffold_views
    %w[ index show new edit _form _index_item]
  end

  def model_name
    class_name.demodulize
  end

  def nesting_owner_class
    nesting_owner.classify
  end

  def plural_name_cap
    plural_name.capitalize
  end

  def singular_name_cap
    singular_name.capitalize
  end

  def nesting_owner_cap
    nesting_owner.capitalize
  end
  def nesting_owner_plural
    nesting_owner.pluralize
  end
  def nesting_owner_plural_cap
    nesting_owner_plural.capitalize
  end

end

module Rails
  module Generator
    class GeneratedAttribute
      def default_value
        @default_value ||= case type
                           when :int, :integer               then "\"1\""
                           when :float                       then "\"1.5\""
                           when :decimal                     then "\"9.99\""
                           when :datetime, :timestamp, :time then "Time.now"
                           when :date                        then "Date.today"
                           when :string                      then "\"MyString\""
                           when :text                        then "\"MyText\""
                           when :boolean                     then "false"
                           else
                             ""
                           end
      end

      def input_type
        @input_type ||= case type
                        when :text                        then "textarea"
                        else
                          "input"
                        end
      end
    end
  end
end
