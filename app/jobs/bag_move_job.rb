class BagMoveJob < ApplicationJob
  def perform(queue_item, src_path, dest_path)
    @queue_item = queue_item
    @src_path = src_path
    @dest_path = dest_path

    begin
      
      # TODO when a bag is just a completed request 
      #  - if all validation succeeds:
      #    - start a transaction that updates the request to complete
      #    - move the bag into place
      #    - success: commit the transaction
      #    - failure (exception) - transaction automatically rolls back
      if bag_is_valid?
        File.rename(src_path,dest_path)
        record_success
      end

    rescue => exception
      record_error(exception.to_s)
      raise exception
    end
  end

  private

  attr_accessor :queue_item, :src_path, :dest_path

  def bag_is_valid?
    bag = ChipmunkBag.new(src_path)
    if bag.valid?
      true
    else
      record_error("Error validating bag:\n" + 
                   indent_array(bag.errors.full_messages))

      false
    end

  end

  def record_error(error)
    queue_item.transaction do
      queue_item.error = error
      queue_item.status = :failed
      queue_item.save!
    end
  end

  def record_success
    queue_item.transaction do
      queue_item.bag = bag_type.create!(
        bag_id: queue_item.request.bag_id,
        user: queue_item.user,
        storage_location: dest_path,
        external_id: queue_item.request.external_id,
      )
      queue_item.status = :done
      queue_item.save!
    end
  end

  def bag_type
    case queue_item.request.content_type
    when :audio
      AudioBag
    when :digital
      DigitalBag
    else
      raise ArgumentError, "there has to be a better way of doing this"
    end
  end

  def indent_array(array,width=2)
    array.map { |s| ' '*width + s }.join("\n")
  end
  
end
