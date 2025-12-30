import jenkins.model.*
import hudson.security.*

def instance = Jenkins.getInstance()

println "--> Enabling security..."

def adminUser = System.getenv("JENKINS_ADMIN_ID") ?: "admin"
def adminPass = System.getenv("JENKINS_ADMIN_PASSWORD")
def realm = new HudsonPrivateSecurityRealm(false)
realm.createAccount(adminUser, adminPass)
instance.setSecurityRealm(realm)

def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
strategy.setAllowAnonymousRead(false)
instance.setAuthorizationStrategy(strategy)

instance.save()

println "--> Security enabled. Admin user created."
