/**
 * GOST Web 管理面板 - 前端逻辑
 */

const API_BASE = '/api';
let protocolTypes = {};
let balanceStrategies = {};
let ssEncrypts = {};
let allRules = [];

// ==================== 初始化 ====================

document.addEventListener('DOMContentLoaded', () => {
    initializePage();
    loadProtocolTypes();
    loadBalanceStrategies();
    loadSSEncrypts();
    
    // 延迟显示欢迎页面内容
    setTimeout(() => {
        refreshStatus();
        loadRules();
        hideWelcomeOverlay();
    }, 2000);
    
    // 定期刷新状态
    setInterval(refreshStatus, 5000);
});

function initializePage() {
    // 设置表单提交事件
    const ruleForm = document.getElementById('ruleForm');
    if (ruleForm) {
        ruleForm.addEventListener('submit', handleSaveRule);
    }
}

function hideWelcomeOverlay() {
    const overlay = document.getElementById('welcomeOverlay');
    if (overlay) {
        overlay.classList.add('hide');
        setTimeout(() => {
            overlay.style.display = 'none';
        }, 500);
    }
}

// ==================== 数据加载 ====================

async function loadProtocolTypes() {
    try {
        const response = await fetch(`${API_BASE}/protocol-types`);
        const data = await response.json();
        protocolTypes = data.data;
        populateProtocolSelect();
    } catch (error) {
        console.error('Error loading protocol types:', error);
    }
}

async function loadBalanceStrategies() {
    try {
        const response = await fetch(`${API_BASE}/balance-strategies`);
        const data = await response.json();
        balanceStrategies = data.data;
    } catch (error) {
        console.error('Error loading balance strategies:', error);
    }
}

async function loadSSEncrypts() {
    try {
        const response = await fetch(`${API_BASE}/ss-encrypts`);
        const data = await response.json();
        ssEncrypts = data.data;
    } catch (error) {
        console.error('Error loading SS encrypts:', error);
    }
}

function populateProtocolSelect() {
    const select = document.getElementById('ruleType');
    select.innerHTML = '<option value="">-- 请选择 --</option>';
    
    Object.entries(protocolTypes).forEach(([key, type]) => {
        const option = document.createElement('option');
        option.value = type.value;
        option.textContent = `${type.name} - ${type.desc}`;
        select.appendChild(option);
    });
}

// ==================== 状态管理 ====================

async function refreshStatus() {
    try {
        const response = await fetch(`${API_BASE}/gost/status`);
        const data = await response.json();
        
        const statusText = document.getElementById('statusText');
        const statusDot = document.querySelector('.status-dot');
        const serviceStatus = document.getElementById('serviceStatus');
        
        const isRunning = data.is_running;

        
        if (isRunning) {
            statusText.textContent = '正在运行';
            statusDot.classList.add('running');
            if (serviceStatus) {
                serviceStatus.innerHTML = '<div style="color: var(--success-color); font-weight: 600; padding: 1rem 0;">✓ 正在运行</div>';
            }
        } else {
            statusText.textContent = '已停止';
            statusDot.classList.remove('running');
            if (serviceStatus) {
                serviceStatus.innerHTML = '<div style="color: var(--danger-color); font-weight: 600; padding: 1rem 0;">✗ 已停止</div>';
            }
        }
        
        // 更新按钮状态
        updateServiceButtons(isRunning);
    } catch (error) {
        console.error('Error fetching status:', error);
    }
}

function updateServiceButtons(isRunning) {
    const startBtn = document.getElementById('startBtn');
    const stopBtn = document.getElementById('stopBtn');
    const restartBtn = document.getElementById('restartBtn');
    
    if (startBtn) startBtn.disabled = isRunning;
    if (stopBtn) stopBtn.disabled = !isRunning;
    if (restartBtn) restartBtn.disabled = !isRunning;
}

// ==================== 规则管理 ====================

async function loadRules() {
    try {
        const response = await fetch(`${API_BASE}/rules`);
        const data = await response.json();
        
        if (data.success) {
            allRules = data.data;
            displayRules(data.data);
            displayRecentRules(data.data);
            updateRuleCount(data.total);
        }
    } catch (error) {
        console.error('Error loading rules:', error);
        showToast('加载规则失败', 'error');
    }
}

function displayRules(rules) {
    const container = document.getElementById('rulesTable');
    
    if (rules.length === 0) {
        container.innerHTML = '<p class="text-center text-muted">暂无规则，<a href="javascript:openAddRuleModal()" style="color: var(--primary-color);">点击添加</a></p>';
        return;
    }
    
    let html = `
        <table class="rules-table">
            <thead>
                <tr>
                    <th>#</th>
                    <th>类型</th>
                    <th>本地端口</th>
                    <th>目标地址</th>
                    <th>目标端口</th>
                    <th>操作</th>
                </tr>
            </thead>
            <tbody>
    `;
    
    rules.forEach((rule) => {
        const typeName = Object.values(protocolTypes).find(t => t.value === rule.type)?.name || rule.type;
        html += `
            <tr>
                <td>${rule.id}</td>
                <td><span style="background-color: var(--light-bg); padding: 0.25rem 0.75rem; border-radius: var(--radius); display: inline-block;">${typeName}</span></td>
                <td><code>${rule.local_port}</code></td>
                <td>${rule.dest_ip}</td>
                <td>${rule.dest_port}</td>
                <td>
                    <div class="rule-actions">
                        <button class="btn btn-sm btn-secondary" onclick="editRule(${rule.id})">
                            <i class="bi bi-pencil"></i> 编辑
                        </button>
                        <button class="btn btn-sm btn-danger" onclick="deleteRule(${rule.id})">
                            <i class="bi bi-trash"></i> 删除
                        </button>
                    </div>
                </td>
            </tr>
        `;
    });
    
    html += `
            </tbody>
        </table>
        <div style="margin-top: 1.5rem; display: flex; justify-content: space-between; align-items: center;">
            <span class="text-muted">共 ${rules.length} 条规则</span>
            <button class="btn btn-success" onclick="applyRules()">
                <i class="bi bi-check-circle"></i> 应用配置并重启
            </button>
        </div>
    `;
    
    container.innerHTML = html;
}

function displayRecentRules(rules) {
    const container = document.getElementById('recentRules');
    
    if (rules.length === 0) {
        container.innerHTML = '<p class="text-muted">暂无规则</p>';
        return;
    }
    
    const recent = rules.slice(0, 3);
    let html = '';
    
    recent.forEach((rule) => {
        const typeName = Object.values(protocolTypes).find(t => t.value === rule.type)?.name || rule.type;
        html += `
            <div class="rule-item">
                <div class="rule-info">
                    <div class="rule-info-item">
                        <span class="rule-info-label">类型</span>
                        <span class="rule-info-value">${typeName}</span>
                    </div>
                    <div class="rule-info-item">
                        <span class="rule-info-label">本地端口</span>
                        <span class="rule-info-value">${rule.local_port}</span>
                    </div>
                    <div class="rule-info-item">
                        <span class="rule-info-label">目标地址</span>
                        <span class="rule-info-value">${rule.dest_ip}</span>
                    </div>
                    <div class="rule-info-item">
                        <span class="rule-info-label">目标端口</span>
                        <span class="rule-info-value">${rule.dest_port}</span>
                    </div>
                </div>
            </div>
        `;
    });
    
    container.innerHTML = html;
}

function updateRuleCount(count) {
    const countElement = document.getElementById('ruleCount');
    if (countElement) {
        countElement.textContent = count;
    }
}

// ==================== 规则编辑 ====================

function openAddRuleModal() {
    document.getElementById('modalTitle').textContent = '添加新规则';
    document.getElementById('ruleForm').reset();
    document.getElementById('ruleForm').dataset.ruleId = '';
    openModal('ruleModal');
}

function editRule(ruleId) {
    const rule = allRules.find(r => r.id === ruleId);
    if (!rule) return;
    
    document.getElementById('modalTitle').textContent = '编辑规则';
    document.getElementById('ruleType').value = rule.type;
    document.getElementById('localPort').value = rule.local_port;
    document.getElementById('destIP').value = rule.dest_ip;
    document.getElementById('destPort').value = rule.dest_port;
    document.getElementById('ruleForm').dataset.ruleId = ruleId;
    
    updateRuleTypeFields();
    openModal('ruleModal');
}

async function deleteRule(ruleId) {
    if (!confirm('确定要删除此规则吗？')) return;
    
    try {
        const response = await fetch(`${API_BASE}/rules/${ruleId}`, {
            method: 'DELETE'
        });
        
        const data = await response.json();
        if (data.success) {
            showToast('规则已删除', 'success');
            loadRules();
        } else {
            showToast(data.error, 'error');
        }
    } catch (error) {
        console.error('Error deleting rule:', error);
        showToast('删除规则失败', 'error');
    }
}

async function handleSaveRule(e) {
    e.preventDefault();
    
    const ruleId = document.getElementById('ruleForm').dataset.ruleId;
    const ruleType = document.getElementById('ruleType').value;
    const localPort = document.getElementById('localPort').value;
    const destIP = document.getElementById('destIP').value;
    const destPort = document.getElementById('destPort').value;
    
    if (!ruleType || !localPort || !destIP || !destPort) {
        showToast('请填写所有必要字段', 'error');
        return;
    }
    
    const ruleData = {
        type: ruleType,
        local_port: localPort,
        dest_ip: destIP,
        dest_port: destPort
    };
    
    try {
        let url = `${API_BASE}/rules`;
        let method = 'POST';
        
        if (ruleId) {
            url = `${API_BASE}/rules/${ruleId}`;
            method = 'PUT';
        }
        
        const response = await fetch(url, {
            method: method,
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(ruleData)
        });
        
        const data = await response.json();
        if (data.success) {
            showToast(ruleId ? '规则已更新' : '规则已添加', 'success');
            closeRuleModal();
            loadRules();
        } else {
            showToast(data.error, 'error');
        }
    } catch (error) {
        console.error('Error saving rule:', error);
        showToast('保存规则失败', 'error');
    }
}

function updateRuleTypeFields() {
    const ruleType = document.getElementById('ruleType').value;
    const typeDesc = document.getElementById('typeDesc');
    const advancedFields = document.getElementById('advancedFields');
    
    advancedFields.innerHTML = '';
    
    // 显示类型描述
    const type = Object.values(protocolTypes).find(t => t.value === ruleType);
    if (type) {
        typeDesc.textContent = type.desc;
    }
}

// ==================== 配置管理 ====================

async function applyRules() {
    if (!confirm('应用配置后GOST服务将重启，是否继续？')) return;
    
    try {
        const response = await fetch(`${API_BASE}/rules/apply`, {
            method: 'POST'
        });
        
        const data = await response.json();
        if (data.success) {
            showToast('配置已应用，GOST已重启', 'success');
            setTimeout(() => {
                refreshStatus();
                loadRules();
            }, 2000);
        } else {
            showToast(data.error, 'error');
        }
    } catch (error) {
        console.error('Error applying rules:', error);
        showToast('应用配置失败', 'error');
    }
}

function copyConfig() {
    const configText = document.getElementById('configPreview').textContent;
    navigator.clipboard.writeText(configText).then(() => {
        showToast('配置已复制到剪贴板', 'success');
    }).catch(() => {
        showToast('复制失败', 'error');
    });
}

// ==================== GOST 服务控制 ====================

async function startGost() {
    try {
        const response = await fetch(`${API_BASE}/gost/start`, {
            method: 'POST'
        });
        
        const data = await response.json();
        if (data.success) {
            showToast('GOST已启动', 'success');
            setTimeout(refreshStatus, 1000);
        } else {
            showToast(data.error, 'error');
        }
    } catch (error) {
        console.error('Error starting GOST:', error);
        showToast('启动GOST失败', 'error');
    }
}

async function stopGost() {
    try {
        const response = await fetch(`${API_BASE}/gost/stop`, {
            method: 'POST'
        });
        
        const data = await response.json();
        if (data.success) {
            showToast('GOST已停止', 'success');
            setTimeout(refreshStatus, 1000);
        } else {
            showToast(data.error, 'error');
        }
    } catch (error) {
        console.error('Error stopping GOST:', error);
        showToast('停止GOST失败', 'error');
    }
}

async function restartGost() {
    await stopGost();
    setTimeout(() => {
        startGost();
    }, 1500);
}

// ==================== UI 交互 ====================

function switchTab(tabName) {
    // 隐藏所有标签页
    const allTabs = document.querySelectorAll('.tab-content');
    allTabs.forEach(tab => tab.classList.remove('active'));
    
    // 移除所有导航项的active类
    const allNavItems = document.querySelectorAll('.nav-item');
    allNavItems.forEach(item => item.classList.remove('active'));
    
    // 显示选中的标签页
    const selectedTab = document.getElementById(tabName);
    if (selectedTab) {
        selectedTab.classList.add('active');
    }
    
    // 添加active类到对应的导航项
    event.target.closest('.nav-item').classList.add('active');
}

function openModal(modalId) {
    const modal = document.getElementById(modalId);
    if (modal) {
        modal.classList.add('active');
    }
}

function closeRuleModal() {
    const modal = document.getElementById('ruleModal');
    if (modal) {
        modal.classList.remove('active');
    }
}

function closeModal(modalId) {
    const modal = document.getElementById(modalId);
    if (modal) {
        modal.classList.remove('active');
    }
}

// 点击模态框外部关闭
document.addEventListener('click', (e) => {
    if (e.target.classList.contains('modal')) {
        e.target.classList.remove('active');
    }
});

// ==================== 提示框 ====================

function showToast(message, type = 'info') {
    const toast = document.getElementById('toast');
    const toastMessage = document.getElementById('toastMessage');
    
    toastMessage.textContent = message;
    toast.className = `toast show ${type}`;
    
    setTimeout(() => {
        toast.classList.remove('show');
    }, 3000);
}

// ==================== 工具函数 ====================

function formatDate(date) {
    return new Date(date).toLocaleString('zh-CN');
}

function escapeHtml(text) {
    const map = {
        '&': '&amp;',
        '<': '&lt;',
        '>': '&gt;',
        '"': '&quot;',
        "'": '&#039;'
    };
    return text.replace(/[&<>"']/g, m => map[m]);
}
