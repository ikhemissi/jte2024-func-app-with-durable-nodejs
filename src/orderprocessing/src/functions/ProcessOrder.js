const { app, output } = require('@azure/functions');
const df = require('durable-functions');

df.app.orchestration('ProcessOrderOrchestrator', function* (context) {
    const order = context.df.getInput();
    context.log(`Processing order ${order.id} in orchestrator`);

    // Fan-out: process each order item in parallel
    const orderItemTasks = order.items.map(item => context.df.callActivity('ProcessOrderItem', item));

    // Fan-in: wait for all order item processing to complete
    const processedItems = yield context.df.Task.all(orderItemTasks);
    
    // Save the processed order to Cosmos DB
    const processedOrder = {
        ...order,
        items: processedItems,
    };

    yield context.df.callActivity('SaveOrder', processedOrder);

    return processedOrder;
});

df.app.activity('ProcessOrderItem', {
    handler: (item) => {
        return {
            ...item,
            status: 'processed',
            processedAt: new Date().toISOString(),
        };
    },
});

const cosmosOutput = output.cosmosDB({
    databaseName: '%COSMOSDB_DATABASE%',
    containerName: '%COSMOSDB_CONTAINER%',
    connection: 'COSMOS_ORDERS',
});

df.app.activity('SaveOrder', {
    return: cosmosOutput,
    handler: (order) => {
        return order;
    },
});

app.serviceBusQueue('ProcessOrderSBStart', {
    queueName: '%SERVICEBUS_QUEUE%',
    connection: 'SB_ORDERS',
    extraInputs: [df.input.durableClient()],
    handler: async (order, context) => {
        const client = df.getClient(context);
        context.log(`Processing order ${order.id}`);
        return instanceId = await client.startNew('ProcessOrderOrchestrator', { input: order });
    },
});