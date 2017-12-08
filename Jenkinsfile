node('docker') {
  checkout scm

  docker.image('docker.io/ruby:2.4.2').inside("-e HOME=${pwd()}") {
    stage('setup') {
      sh 'bundle install'
    }
    stage('rubocop') {
      sh 'bundle exec rubocop'
    }
    stage('rspec') {
      sh 'bundle exec rspec --format doc'
    }
  }
}
