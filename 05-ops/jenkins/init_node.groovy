import hudson.model.Node.Mode
import hudson.slaves.*
import jenkins.model.Jenkins

String agentName = "docker-agent-1"
Jenkins jenkins = Jenkins.getInstance()
def node = jenkins.getNode(agentName)

if (node == null) {
    println "Creating node: " + agentName
    JNLPLauncher launcher = new JNLPLauncher(false)
    DumbSlave newSlave = new DumbSlave(
            agentName,
            "Static Agent for Docker",
            "/home/jenkins/agent",
            "2",
            Mode.NORMAL,
            "docker-agent-1 linux docker",
            launcher,
            new RetentionStrategy.Always(),
            new LinkedList()
    )
    jenkins.addNode(newSlave)
    node = newSlave
}

// Ensure secret is written to shared volume
def computer = node.toComputer()
if (computer != null) {
    def secret = computer.getJnlpMac()
    File dir = new File("/var/jenkins_home/agent_share")
    if (!dir.exists()) {
        dir.mkdirs()
    }
    new File("/var/jenkins_home/agent_share/secret-docker-agent-1").text = secret
    println "Secret written to /var/jenkins_home/agent_share/secret-docker-agent-1: " + secret
} else {
    println "Error: Computer for " + agentName + " is null"
}
