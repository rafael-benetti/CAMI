# VPN L2TP/IPsec no iPhone e iPad

O Android e o iOS usam perfis independentes neste projeto:

- Android: IKEv2/PSK, compilado no APK a partir de CAMI_VPN_SERVER,
  CAMI_VPN_REMOTE_ID e CAMI_VPN_PSK.
- iOS: L2TP sobre IPsec com conta, senha e segredo compartilhado.

O iOS não permite que um aplicativo Flutter crie ou conecte automaticamente um
perfil L2TP. A forma suportada pela Apple é instalar um perfil de configuração
do sistema. O gerador deste projeto cria esse perfil exclusivamente na máquina
local, sem adicionar credenciais ao Git ou ao IPA.

## Gerar o perfil local

Em android/local.properties, mantenha estes campos preenchidos:

~~~properties
CAMI_VPN_SERVER=ENDERECO_DO_SERVIDOR
CAMI_VPN_REMOTE_ID_IOS=CONTA_L2TP
CAMI_VPN_REMOTE_SENHA_IOS=SENHA_DA_CONTA
CAMI_VPN_REMOTE_SEGREDO_IOS=SEGREDO_COMPARTILHADO
~~~

Execute na raiz de FlucamSecurityCameraApp:

~~~bash
dart run tool/generate_ios_l2tp_profile.dart
plutil -lint ios/CAMI-L2TP.mobileconfig
~~~

O resultado fica em ios/CAMI-L2TP.mobileconfig, com permissão local 0600 e
ignorado pelo Git. Ele contém senha e segredo em texto claro, pois o sistema
precisa deles para instalar a configuração. Não o envie por mensageiro, e-mail
ou repositório público.

## Instalar e conectar

Transfira o arquivo para o iPhone/iPad por um canal seguro. Abra-o no aparelho,
autorize a instalação em **Ajustes**, instale o perfil e conecte a VPN em
**Ajustes > Geral > VPN e Gerenciamento de Dispositivo > VPN** antes de abrir
o CAMI fora da rede privada.

O app detecta quando o Frigate já está alcançável. Se ele não estiver, no iOS
a conexão L2TP continua sendo controlada pelo sistema; o aplicativo não pode
ativá-la silenciosamente.

Consulte a documentação da Apple para as configurações L2TP aceitas em perfis
de dispositivo.

