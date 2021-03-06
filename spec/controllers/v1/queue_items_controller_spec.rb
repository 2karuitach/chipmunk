require 'rails_helper'

RSpec.describe V1::QueueItemsController, type: :controller do
  describe "/v1" do

    pending_proc = proc do |user|
      if user
        Fabricate(:queue_item,
          bag: nil,
          request: Fabricate(:request, user: user))
      else
        Fabricate(:queue_item, bag: nil)
      end
    end

    done_proc = proc do |user|
      uuid = SecureRandom.uuid
      if user
        Fabricate(:queue_item,
          bag: Fabricate(:bag, bag_id: uuid, user: user),
          request: Fabricate(:request, bag_id: uuid, user: user)
        )
      else
        Fabricate(:queue_item,
          bag: Fabricate(:bag, bag_id: uuid),
          request: Fabricate(:request, bag_id: uuid)
        )
      end
    end

    describe "GET #index" do
      it_behaves_like "an index endpoint" do
        before(:each) do
          # We invoke the done_proc here to add an additional,
          # non-pending (complete) QueueItem.  Its existence
          # will cause the tests to fail if it is retrieved by
          # the index endpoint.
          # This is a hack.
          done_proc.call(user)
        end
        let(:key) { :id }
        let(:factory) { pending_proc }
        let(:assignee) { :queue_items }
      end
    end

    describe "GET #show" do
      context "queue_item has no bag (is incomplete)" do
        it_behaves_like "a show endpoint" do
          let(:key) { :id }
          let(:factory) { pending_proc }
          let(:assignee) { :queue_item }
        end
      end

      context "queue_item has a bag (is complete)" do
        it_behaves_like "a show endpoint" do
          let(:key) { :id }
          let(:factory) { done_proc }
          let(:assignee) { :queue_item }
        end
      end

    end

    describe "POST #create" do


      def owned_request
        Fabricate(:request, bag_id: attributes[:bag_id], user: user)
      end

      def unowned_request
        Fabricate(:request, bag_id: attributes[:bag_id])
      end

      def invalid_queue_item
        record = Fabricate(:queue_item, request: request_record)
        record.errors.add(:bag, message: "test_error")
        record
      end

      def valid_queue_item
        Fabricate(:queue_item, request: request_record) 
      end

      shared_examples_for "an empty response" do
        it "renders nothing" do
          post :create, params: attributes
          expect(response).to render_template(nil)
        end
      end

      shared_examples_for "a redirect" do
        it "correctly sets location header" do
          post :create, params: attributes
          expect(response.location).to eql(v1_queue_item_url(expected_queue_item))
        end
        it_behaves_like "an empty response"
      end

      shared_examples_for "a 403 empty response" do
        it "returns 403" do
          post :create, params: attributes
          expect(response).to have_http_status(403)
        end
        it_behaves_like "an empty response"
      end


      shared_examples_for "with duplicate item, returns a 303 redirect with no new item" do
        let!(:request_record) { owned_request }
        let!(:expected_queue_item) { valid_queue_item }

        it "does not invoke QueueItemBuilder" do
          expect(QueueItemBuilder).to_not receive(:new)
          post :create, params: attributes
        end

        it "does not create an additional record" do
          post :create, params: attributes
          expect(QueueItem.count).to eql(1)
        end

        it "returns 303" do
          post :create, params: attributes
          expect(response).to have_http_status(303)
        end
        it_behaves_like "a redirect"
      end

      shared_examples_for "an item that returns 201 on success and 422 on failure" do
        context "when the QueueItem can be saved" do
          let(:expected_queue_item) { Fabricate(:queue_item, request: request_record) }
          it "returns 201" do
            post :create, params: attributes
            expect(response).to have_http_status(201)
          end
          it_behaves_like "a redirect"
        end

        context "when the QueueItem cannot be saved" do
          let(:expected_queue_item) { invalid_queue_item }
          it "returns 422" do
            post :create, params: attributes
            expect(response).to have_http_status(422)
          end
          it_behaves_like "an empty response"
        end
      end

      let(:attributes) {{ bag_id: SecureRandom.uuid }}
      let(:builder) { double(:builder, build: nil) }

      before(:each) do
        allow(QueueItemBuilder).to receive(:new).and_return(builder)
        request.headers.merge! auth_header
      end

      context "as unauthenticated user" do
        include_context "as unauthenticated user"
        it "returns 401" do
          post :create, params: attributes
          expect(response).to have_http_status(401)
        end
        it_behaves_like "an empty response"
        it "does not create the record" do
          post :create, params: attributes
          expect(QueueItem.count).to eql(0)
        end
      end

      context "with mocked builder create" do
        before(:each) { allow(builder).to receive(:create).with(request_record).and_return(expected_queue_item) }

        context "as underprivileged user" do
          include_context "as underprivileged user"

          it_behaves_like "with duplicate item, returns a 303 redirect with no new item"

          context "new record" do
            before(:each) { allow(QueueItem).to receive_message_chain(:joins, :find_by).and_return nil }

            context "user owns request" do
              let(:request_record) { owned_request }
              it_behaves_like "an item that returns 201 on success and 422 on failure"
            end

            context "user does not own request" do
              let(:request_record) { unowned_request }

              context "user does not own request, success" do
                let(:expected_queue_item) { valid_queue_item }
                it_behaves_like "a 403 empty response"
              end

              context "user does not own request, failure" do
                let(:expected_queue_item) { invalid_queue_item }
                it_behaves_like "a 403 empty response"
              end
            end
          end

        end

        context "as admin user" do
          include_context "as admin user"

          it_behaves_like "with duplicate item, returns a 303 redirect with no new item"

          context "new record" do
            before(:each) { allow(QueueItem).to receive_message_chain(:joins, :find_by).and_return nil }

            context "when user owns the request" do
              let(:request_record) { owned_request }
              it_behaves_like "an item that returns 201 on success and 422 on failure"
            end

            context "when the user does not own the request" do
              let(:request_record) { unowned_request }
              it_behaves_like "an item that returns 201 on success and 422 on failure"
            end

          end

        end

      end

    end
  end
end
