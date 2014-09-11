module VagrantPlugins
	module Proxmox
		module Action

			# This action creates a new virtual machine on the Proxmox server and
			# stores its node and vm_id env[:machine].id
			class CreateVm < ProxmoxAction

				def initialize app, env
					@app = app
					@logger = Log4r::Logger.new 'vagrant_proxmox::action::create_vm'
				end

				def call env
					env[:ui].info I18n.t('vagrant_proxmox.creating_vm')
					config = env[:machine].provider_config

					node = env[:proxmox_selected_node]
					vm_id = nil

					begin
						vm_id = connection(env).get_free_vm_id

						if config.vm_type == :openvz
							params = {vmid: vm_id,
												ostemplate: config.openvz_os_template,
												hostname: env[:machine].config.vm.hostname || env[:machine].name.to_s,
												password: 'vagrant',
												memory: config.vm_memory,
												description: "#{config.vm_name_prefix}#{env[:machine].name}"}
							params[:ip_address] = get_machine_ip_address(env) if get_machine_ip_address(env)
						elsif config.vm_type == :qemu
							network = 'e1000,bridge=vmbr0'
							network = "e1000=#{get_machine_macaddress(env)},bridge=vmbr0" if get_machine_macaddress(env)
							params = {vmid: vm_id,
												name: env[:machine].config.vm.hostname || env[:machine].name.to_s,
												ostype: config.qemu_os,
												ide2: "#{config.qemu_iso},media=cdrom",
												sata0: "raid:#{convert_disk_size_to_gigabyte config.qemu_disk_size},format=qcow2",
												sockets: 1,
												cores: 1,
												memory: config.vm_memory,
												net0: network,
												description: "#{config.vm_name_prefix}#{env[:machine].name}"}
						end

						exit_status = connection(env).create_vm node: node, vm_type: config.vm_type, params: params
						exit_status == 'OK' ? exit_status : raise(VagrantPlugins::Proxmox::Errors::ProxmoxTaskFailed, proxmox_exit_status: exit_status)
					rescue StandardError => e
						raise VagrantPlugins::Proxmox::Errors::VMCreateError, proxmox_exit_status: e.message
					end

					env[:machine].id = "#{node}/#{vm_id}"

					env[:ui].info I18n.t('vagrant_proxmox.done')
					next_action env
				end

				private
				def convert_disk_size_to_gigabyte disk_size
					case disk_size[-1]
						when 'G'
							disk_size[0..-2]
					end
				end
			end
		end
	end
end
