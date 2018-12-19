#!/usr/bin/env ruby

# Build the dockerfile in the current directory
# Upload it to the `REPOSITORY_ADDRESS` with the `REPOSITORY_NAME` and `TAG`
# Update the tag for the uploaded image in the task definition for `task_family`
# Update the service named `service` to use the updated task definition

require 'json'
require 'open3'

# These should change from project to project
REPOSITORY_NAME = "nginx-sidecar".freeze
DELETE_LOG_CONFIGURATION = true
ECS_OBJECTS = [
  {
    task_family: "evalog",
    service: "evalog",
  },
  {
    task_family: "barstack",
    service: "barstack",
  },
  {
    task_family: "bloopist",
    service: "bloopist",
  },
  {
    task_family: "pricer-pro",
    service: "pricer-pro",
  },
].freeze

# These probably won't change from project to project
CLUSTER = "kurttomlinson-cluster".freeze
REPOSITORY_ADDRESS = "541693649649.dkr.ecr.us-east-1.amazonaws.com/".freeze

# These should never change
TAG = Time.now.strftime("%y%m%d-%H%M").freeze
TASK_DEFINITION_PATH = File.expand_path(File.dirname(__FILE__)) + "/task_definitions/"

def divider
  puts "====================\n"
end

def login_to_ecr
  puts "Logging in to ECR"
  login_command = `aws ecr get-login --no-include-email`
  login_result = `#{login_command}`
  puts login_result
  divider
end

def build_image
  build_command = "docker build -t #{REPOSITORY_ADDRESS}#{REPOSITORY_NAME}:#{TAG} ."
  run_command(build_command)
end

def push_image
  push_command = "docker push #{REPOSITORY_ADDRESS}#{REPOSITORY_NAME}:#{TAG}"
  run_command(push_command)
end

def run_command(command)
  puts "Running command: #{command}\n\n"
  Open3.popen2e(command) do |_stdin, stdout_err, _wait_thr|
    while line = stdout_err.gets
      puts line
    end
  end
  divider
end

def generate_task_definition(task_family)
  puts "Creating task definition..."
  task_definition = JSON.parse(`aws ecs describe-task-definition --task-definition #{task_family}`)["taskDefinition"]
  task_definition_revision = task_definition.dig("revision") + 1

  task_definition.keep_if { |key, value| ["family", "containerDefinitions"].include?(key) }

  task_definition["containerDefinitions"].each do |container_definition|
    if container_definition["image"] =~ /#{REPOSITORY_ADDRESS}#{REPOSITORY_NAME}:/
      container_definition["image"] = "#{REPOSITORY_ADDRESS}#{REPOSITORY_NAME}:#{TAG}"
    end
    container_definition.delete "logConfiguration" if DELETE_LOG_CONFIGURATION
  end

  Dir.mkdir(TASK_DEFINITION_PATH) unless Dir.exist? TASK_DEFINITION_PATH

  task_definition_filename = "#{TASK_DEFINITION_PATH}#{task_family}:#{task_definition_revision}.json"
  File.open(task_definition_filename, 'w') { |f| f.write(task_definition.to_json) }
  puts "Created task definition: #{task_definition_filename}"
  divider
  task_definition_filename
end

def register_task_definition(task_definition_filename)
  puts "Registering new task definition..."
  register_command = "aws ecs register-task-definition " +
                     "--cli-input-json file://#{task_definition_filename}"
  register_result = `#{register_command}`
  puts register_result
  divider
  JSON.parse(register_result)["taskDefinition"]["taskDefinitionArn"]
end

def update_service(task_definition_arn, service)
  update_command = "aws ecs update-service " +
                   "--cluster #{CLUSTER} " + 
                   "--service #{service} " +
                   "--task-definition #{task_definition_arn}"
  run_command(update_command)
end

login_to_ecr
build_image
push_image

ECS_OBJECTS.each do |ecs_objects|
  task_family = ecs_objects[:task_family]
  service = ecs_objects[:service]
  task_definition_filename = generate_task_definition(task_family)
  task_definition_arn = register_task_definition(task_definition_filename)
  update_service(task_definition_arn, service)
end
