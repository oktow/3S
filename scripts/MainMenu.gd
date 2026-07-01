extends Control

@onready var name_input: LineEdit = $TextureRect/VBoxContainer/NameInput
@onready var ip_input: LineEdit = $TextureRect/VBoxContainer/IPInput
@onready var ip_label: Label = $TextureRect/VBoxContainer/IPLabel
@onready var status_label: Label = $TextureRect/VBoxContainer/StatusLabel
@onready var server_list: VBoxContainer = $TextureRect/VBoxContainer/ServerListContainer/ServerList
@onready var refresh_timer: Timer = $RefreshTimer

var udp_broadcaster: PacketPeerUDP


func _ready() -> void:
	NetworkManager.player_connected.connect(_on_game_started)
	NetworkManager.server_disconnected.connect(_on_server_disconnected)

	udp_broadcaster = PacketPeerUDP.new()
	udp_broadcaster.set_broadcast_enabled(true)
	udp_broadcaster.set_dest_address("255.255.255.255", NetworkManager.DISCOVERY_PORT)

	start_listening_for_broadcasts()
	ip_label.text = "IP Anda: %s" % _get_local_ip()


func start_listening_for_broadcasts() -> void:
	var listen: PacketPeerUDP = PacketPeerUDP.new()
	listen.bind(NetworkManager.DISCOVERY_PORT)
	# Store for polling
	set_meta("listen_peer", listen)


func _process(_delta: float) -> void:
	var listen: PacketPeerUDP = get_meta("listen_peer", null)
	if listen and listen.get_available_packet_count() > 0:
		var packet: PackedByteArray = listen.get_packet()
		var host_ip: String = listen.get_packet_ip()
		var msg: String = packet.get_string_from_utf8()
		if msg == "3S_SERVER_DISCOVER":
			_add_server_to_list(host_ip)


func _add_server_to_list(ip: String) -> void:
	for child in server_list.get_children():
		if child is Button and child.text.contains(ip):
			return

	var btn: Button = Button.new()
	btn.text = "Join %s" % ip
	btn.pressed.connect(func():
		_join_ip(ip)
	)
	server_list.add_child(btn)


func _get_local_ip() -> String:
	var interfaces: Array = IP.get_local_interfaces()
	var candidates: Array[String] = []

	for iface in interfaces:
		var friendly: String = iface.get("friendly", "").to_lower()
		var iface_name: String = iface.get("name", "").to_lower()
		var combined: String = friendly + " " + iface_name

		# Skip adapter virtual / VPN
		if "virtual" in combined or "vmware" in combined or "virtualbox" in combined:
			continue
		if "docker" in combined or "tailscale" in combined or "vEthernet" in combined:
			continue
		if "bluetooth" in combined or "loopback" in combined or "localhost" in combined:
			continue
		if "pbl" in combined or "isatap" in combined or "teredo" in combined:
			continue

		# Ambil IPv4 dari interface ini
		for addr: String in iface["addresses"]:
			if addr.begins_with("127.") or addr.begins_with("169.254."):
				continue
			if "." in addr:
				candidates.append(addr)

	if not candidates.is_empty():
		return candidates[0]

	# Fallback: ambil IPv4 pertama yg bukan loopback
	for addr: String in IP.get_local_addresses():
		if addr.begins_with("127."):
			continue
		if "." in addr:
			return addr
	return "Tidak diketahui"


func _get_player_name() -> String:
	var p_name: String = name_input.text.strip_edges()
	if p_name.is_empty():
		return "Player"
	return p_name


func _on_edit_character_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/PlayerEditor.tscn")


func _on_create_pressed() -> void:
	status_label.text = "Hosting..."
	NetworkManager.player_name = _get_player_name()
	NetworkManager.host()
	_broadcast_presence()
	get_tree().change_scene_to_file("res://scenes/Lobby.tscn")


func _broadcast_presence() -> void:
	var data: PackedByteArray = "3S_SERVER_DISCOVER".to_utf8_buffer()
	udp_broadcaster.put_packet(data)


func _on_join_pressed() -> void:
	var ip: String = ip_input.text.strip_edges()
	if ip.is_empty():
		status_label.text = "Masukkan IP Address!"
		return
	_join_ip(ip)


func _join_ip(ip: String) -> void:
	status_label.text = "Connecting to %s..." % ip
	NetworkManager.player_name = _get_player_name()
	NetworkManager.join(ip)


func _on_game_started(_peer_id: int) -> void:
	get_tree().change_scene_to_file("res://scenes/Lobby.tscn")


func _on_server_disconnected() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


func _on_refresh_pressed() -> void:
	for child in server_list.get_children():
		child.queue_free()
	status_label.text = "Scanning..."
	var listen: PacketPeerUDP = PacketPeerUDP.new()
	listen.bind(NetworkManager.DISCOVERY_PORT)
	set_meta("listen_peer", listen)
	_broadcast_presence()
	refresh_timer.start(2.0)


func _on_refresh_timer_timeout() -> void:
	status_label.text = ""
