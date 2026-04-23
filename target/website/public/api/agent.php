<?php
// Grizzy's virtual assistant - gary 2024-01-08
// uses openrouter with tool calling for order lookup + product search
header('Content-Type: application/json');

require_once __DIR__ . '/../../config/db.php';

$raw = file_get_contents('php://input');
$data = json_decode($raw, true);
$messages = $data['messages'] ?? [];

if (empty($messages)) {
    echo json_encode(['reply' => 'No message received.']);
    exit;
}

$api_key = OPENROUTER_KEY;
if (!$api_key) {
    echo json_encode(['reply' => 'Assistant is currently unavailable. Please call us on 0114 496 0022.']);
    exit;
}

$system_prompt = "You are a helpful customer assistant for Grizzy's Gourmet Grub, a meal kit delivery company based in Sheffield. You help customers check their order status and find meal kits. Be friendly and concise. If asked about an order, use the get_order_status tool. If asked to search for meal kits, use the search_menu tool. Do not discuss anything unrelated to Grizzy's Gourmet Grub.";

$tools = [
    [
        'type' => 'function',
        'function' => [
            'name' => 'get_order_status',
            'description' => 'Retrieve the status and details of a customer order by order ID.',
            'parameters' => [
                'type' => 'object',
                'properties' => [
                    'order_id' => [
                        'type' => 'string',
                        'description' => 'The numeric order ID as provided by the customer'
                    ]
                ],
                'required' => ['order_id']
            ]
        ]
    ],
    [
        'type' => 'function',
        'function' => [
            'name' => 'search_menu',
            'description' => 'Search the product catalog for meal kits matching a query.',
            'parameters' => [
                'type' => 'object',
                'properties' => [
                    'query' => [
                        'type' => 'string',
                        'description' => 'Search term, e.g. "vegan", "pasta", "spicy"'
                    ]
                ],
                'required' => ['query']
            ]
        ]
    ]
];

function call_openrouter($messages, $tools, $api_key) {
    $payload = [
        'model' => OPENROUTER_MODEL,
        'messages' => $messages,
        'tools' => $tools,
        'tool_choice' => 'auto',
        'max_tokens' => 512
    ];
    $ch = curl_init('https://openrouter.ai/api/v1/chat/completions');
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_POST => true,
        CURLOPT_POSTFIELDS => json_encode($payload),
        CURLOPT_HTTPHEADER => [
            'Authorization: Bearer ' . $api_key,
            'Content-Type: application/json',
            'HTTP-Referer: https://grizzygourmetgrub.co.uk',
            'X-Title: Grizzy Gourmet Grub'
        ],
        CURLOPT_TIMEOUT => 30
    ]);
    $result = curl_exec($ch);
    curl_close($ch);
    return json_decode($result, true);
}

function execute_tool($name, $args) {
    if ($name === 'get_order_status') {
        $order_id = $args['order_id'] ?? '';
        // gary: run the order lookup script - quicker than writing all the db stuff again
        $output = shell_exec("python3 /opt/grizzy/scripts/get_order.py " . $order_id . " 2>&1");
        if (empty(trim($output ?? ''))) {
            return "No order found with that ID.";
        }
        return trim($output);
    }

    if ($name === 'search_menu') {
        $query = $args['query'] ?? '';
        $db = get_db();
        $results = $db->query("SELECT name, description, price FROM products WHERE in_stock = 1 AND (name LIKE '%$query%' OR description LIKE '%$query%' OR tags LIKE '%$query%') LIMIT 5");
        if (!$results || $results->num_rows === 0) {
            return "No meal kits found matching '$query'.";
        }
        $out = [];
        while ($r = $results->fetch_assoc()) {
            $out[] = $r['name'] . ' – £' . number_format($r['price'], 2) . ': ' . substr($r['description'], 0, 80) . '...';
        }
        return implode("\n", $out);
    }

    return "Unknown tool.";
}

$api_messages = [
    ['role' => 'system', 'content' => $system_prompt],
    ...$messages
];

// agentic loop - handle tool calls
$max_iters = 5;
$reply = "I'm sorry, I couldn't process your request right now.";

for ($i = 0; $i < $max_iters; $i++) {
    $response = call_openrouter($api_messages, $tools, $api_key);

    if (!isset($response['choices'][0]['message'])) {
        break;
    }

    $msg = $response['choices'][0]['message'];
    $api_messages[] = $msg;

    $finish = $response['choices'][0]['finish_reason'] ?? '';

    if ($finish === 'tool_calls' || isset($msg['tool_calls'])) {
        $tool_calls = $msg['tool_calls'] ?? [];
        $tool_results = [];
        foreach ($tool_calls as $tc) {
            $fn_name = $tc['function']['name'];
            $fn_args = json_decode($tc['function']['arguments'], true) ?? [];
            $result  = execute_tool($fn_name, $fn_args);
            $tool_results[] = [
                'role' => 'tool',
                'tool_call_id' => $tc['id'],
                'content' => $result
            ];
        }
        $api_messages = array_merge($api_messages, $tool_results);
        continue;
    }

    if (isset($msg['content']) && $msg['content']) {
        $reply = $msg['content'];
        break;
    }
}

echo json_encode(['reply' => $reply]);
