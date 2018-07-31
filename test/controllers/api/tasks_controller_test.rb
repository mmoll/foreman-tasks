require 'foreman_tasks_test_helper'

module ForemanTasks
  class Api::TasksControllerTest < ActionController::TestCase
    describe 'tasks api controller' do
      tests ForemanTasks::Api::TasksController

      before do
        User.current = User.where(:login => 'apiadmin').first
        @request.env['HTTP_ACCEPT'] = 'application/json'
        @request.env['CONTENT_TYPE'] = 'application/json'
      end

      describe 'GET /api/tasks/show' do
        it 'searches for task' do
          task = FactoryBot.create(:dynflow_task, :user_create_task)
          get :show, params: { :id => task.id }
          assert_response :success
          assert_template 'api/tasks/show'
        end

        it 'search for non-existent task' do
          get :show, params: { :id => 'abc123' }
          assert_response :missing
          assert_includes @response.body, 'Resource task not found by id'
        end
      end

      describe 'GET /api/tasks/summary' do
        class DummyTestSummaryAction < Support::DummyDynflowAction
          # a dummy test action that do nothing
          def run
            # a dummy run method
          end
        end

        it 'get tasks summary' do
          ForemanTasks.trigger(DummyTestSummaryAction)
          get :summary
          assert_response :success
          response = JSON.parse(@response.body)
          assert_kind_of Array, response
          refute response.empty?
          assert_kind_of Hash, response[0]
        end
      end

      describe 'POST /tasks/callback' do
        it 'passes the data to the corresponding action' do
          Support::DummyProxyAction.reset

          triggered = ForemanTasks.trigger(Support::DummyProxyAction,
                                           Support::DummyProxyAction.proxy,
                                           'Proxy::DummyAction',
                                           'foo' => 'bar')
          Support::DummyProxyAction.proxy.task_triggered.wait(5)

          task = ForemanTasks::Task.where(:external_id => triggered.id).first
          task.state.must_equal 'running'
          task.result.must_equal 'pending'

          callback = Support::DummyProxyAction.proxy.log[:trigger_task].first[1][:callback]
          post :callback, params: { 'callback' => callback, 'data' => { 'result' => 'success' } }
          triggered.finished.wait(5)

          task.reload
          task.state.must_equal 'stopped'
          task.result.must_equal 'success'
          task.main_action.output['proxy_task_id'].must_equal Support::DummyProxyAction.proxy.uuid
          task.main_action.output['proxy_output'].must_equal('result' => 'success')
        end
      end
    end
  end
end
