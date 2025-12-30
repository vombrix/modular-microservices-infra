import hudson.model.Node.Mode
import hudson.slaves.*
import jenkins.model.Jenkins

String agentName = "docker-agent-1"
String agentDescription = "Static Agent for Docker"
String agentHome = "/home/jenkins/agent"
String label = "docker-agent-1"
int numExecutors = 1

Jenkins jenkins = Jenkins.getInstance()
if (jenkins.getNode(agentName) == null) {
    println "Creating node: " + agentName
    
    // Create JNLP Launcher
    JNLPLauncher launcher = new JNLPLauncher(false)
    
    // Create DumbSlave
    DumbSlave newSlave = new DumbSlave(
            agentName,
            agentDescription,
            agentHome,
            String.valueOf(numExecutors),
            Mode.NORMAL,
            label,
            launcher,
            new RetentionStrategy.Always(),
            new LinkedList()
    )
    
    jenkins.addNode(newSlave)
    println "Node created successfully."
    
    // Write secret to shared volume
    def computer = newSlave.toComputer()
    if (computer != null) {
        def secret = computer.getJnlpMac()
        new File("/var/jenkins_home/agent_share/secret-docker-agent-1").text = secret
        println "Secret written to /var/jenkins_home/agent_share/secret-docker-agent-1"
    }
} else {
    println "Node " + agentName + " already exists."
    // Ensure secret is written even if node exists
    def node = jenkins.getNode(agentName)
    def computer = node.toComputer()
    if (computer != null) {
        def secret = computer.getJnlpMac()
        new File("/var/jenkins_home/agent_share/secret-docker-agent-1").text = secret
        println "Secret updated in /var/jenkins_home/agent_share/secret-docker-agent-1"
    }
}
