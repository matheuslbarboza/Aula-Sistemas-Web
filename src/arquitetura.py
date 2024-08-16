
from diagrams import Cluster, Diagram
from diagrams.aws.compute import Lambda
from diagrams.aws.database import Dynamodb
from diagrams.aws.storage import S3
from diagrams.aws.network import ELB, APIGateway, CloudFront
from diagrams.onprem.client import Users
from diagrams.onprem.network import Internet
from diagrams.aws.database import Elasticache

with Diagram("Arquitetura de serviço de pedido de pizza", show=False):
    # Camada de Interação com o Cliente
    users = Users("Aplicativo mobile")
    web = Users("Site web")

    # Load Balancer e API Gateway
    lb = ELB("Load Balancer")
    api_gateway = APIGateway("API Gateway")

    # Cache adicionado
    cache = Elasticache("Cache")

    # Camada de Processamento de Pedidos
    with Cluster("Serviços"):
        order_service = Lambda("Serviço de pedido")
        payment_service = Lambda("Serviço de pagamento")
        
        with Cluster("Notification Cluster"):
            notification_service = Lambda("Serviço de notificação")
        
        # Novo serviço de entrega
        delivery_service = Lambda("Serviço de delivery")

    # Armazenamento e Integração de Dados
    store = S3("Order Store")
    db = Dynamodb("Order Database")

    # Fluxo de Dados
    users >> lb >> api_gateway >> order_service
    web >> lb
    
    order_service >> payment_service
    order_service >> notification_service
    order_service >> delivery_service  # Conectando o Order Service ao Delivery Service
    order_service >> store
    order_service >> db

    # Conectando o Cache e o Cluster de Notificações
    cache >> notification_service
    notification_service >> db
    
    # Conexão do Delivery Service
    delivery_service >> db
