module Puppet
  newtype(:cs_order) do
    @doc = "Type for manipulating Corosync/Pacemkaer ordering entries.  Order
      entries are another type of constraint that can be put on sets of
      primitives but unlike colocation, order does matter.  These designate
      the order at which you need specific primitives to come into a desired
      state before starting up a related primitive.

      More information can be found at the following link:

      * http://www.clusterlabs.org/doc/en-US/Pacemaker/1.1/html/Clusters_from_Scratch/_controlling_resource_start_stop_ordering.html"

    ensurable

    newparam(:name) do
      desc "Name identifier of this ordering entry.  This value needs to be unique
        across the entire Corosync/Pacemaker configuration since it doesn't have
        the concept of name spaces per type."
      isnamevar
    end

    newproperty(:resources, :array_matching => :all) do
      desc "List of resources (primitives, ms, etc) to be started in a specific order.
        Must supply at least two resources."

      # Have to redefine should= here so we can sort the array that is given to
      # us by the manifest.  While were checking on the class of our value we
      # are going to go ahead and do some validation too.  The way Corosync
      # order works we need to only accept two value or more arrays.
      def should=(value)
        super
        if value.is_a? Array
          raise Puppet::Error, "Puppet::Type::Cs_Order: The primitives property must be at least a two value array." unless value.size >= 2
          @should.sort!
        else
          raise Puppet::Error, "Puppet::Type::Cs_Order: The primitives property must be at least a two value array."
          @should
        end
      end
    end

    newparam(:cib) do
      desc "Corosync applies its configuration immediately. Using a CIB allows
        you to group multiple primitives and relationships to be applied at
        once. This can be necessary to insert complex configurations into
        Corosync correctly.

        This paramater sets the CIB this order should be created in. A
        cs_shadow resource with a title of the same name as this value should
        also be added to your manifest."
    end

    newproperty(:score) do
      desc "The priority of the this ordered grouping.  Primitives can be a part
        of multiple order groups and so there is a way to control which
        primitives get priority when forcing the order of state changes on
        other primitives.  This value can be an integer but is often defined
        as the string INFINITY."

      defaultto 'INFINITY'
    end

    autorequire(:cs_shadow) do
      [ @parameters[:cib] ]
    end
    newproperty(:symmetrical) do
      desc "Boolean specifying if the resources should stop in reverse order.
        Default value: true."
      defaultto true
    end

    valid_resource_types = [:cs_primitive, :cs_group]
    newparam(:resources_type) do
      desc "String to specify which HA resource type is used for this order,
        e.g. when you want to order groups (cs_group) instead of primitives.
        Defaults to cs_primitive."

      defaultto :cs_primitive
      validate do |value|
        valid_resource_types.include? value
      end
    end

    autorequire(:service) do
      [ 'corosync' ]
    end

    valid_resource_types.each{ |possible_resource_type|
      # We're generating autorequire blocks for all possible cs_ types because
      # accessing the @parameters[:resources_type].value doesn't seem possible
      # when the type is declared. Feel free to improve this.
      autorequire(possible_resource_type) do
        autos = []
        resource_type = @parameters[:resources_type].value
        if resource_type.to_sym == possible_resource_type.to_sym
	  @parameters[:resources].should.each do |val|
	    autos << unmunge_cs_resourcename(val)
	  end
        end

        autos
      end
    }

    def unmunge_cs_resourcename(name)
      name = name.split(':')[0]
      if name.start_with? 'ms_'
        name = name[3..-1]
      end

      name
    end
  end
end
