// 导入配置项
import { config } from './config.js';

document.addEventListener('DOMContentLoaded', () => {
    const { createApp, ref, reactive, computed } = Vue;

    createApp({
        setup() {
            // 搜索表单数据
            const searchForm = reactive({
                callsign: ''
            });

            // 搜索表单验证规则
            const searchRules = {
                callsign: [
                    { required: true, message: 'Please enter a callsign', trigger: 'blur' },
                    {
                        pattern: /^[A-Za-z0-9]{4,8}$/,
                        message: 'Callsign must be 4-8 alphanumeric characters',
                        trigger: ['blur', 'change']
                    }
                ]
            };

            // 状态变量
            const searchFormRef = ref(null);
            const searchResults = ref([]);
            const isLoading = ref(false);
            const searchError = ref('');
            const hasSearched = ref(false);

            // 输入过滤（只允许字母和数字）
            const filterInput = () => {
                searchForm.callsign = searchForm.callsign
                    .replace(/[^A-Za-z0-9]/g, '') // 移除非字母数字字符
                    .substring(0, 8); // 限制最大长度为8
            };

            // 检查输入是否有效
            const isInputValid = computed(() => {
                return /^[A-Za-z0-9]{4,8}$/.test(searchForm.callsign);
            });

            // 格式化日期显示
            const formatDate = (dateString) => {
                if (!dateString) return 'N/A';
                const date = new Date(dateString);
                return date.toLocaleDateString('en-US', {
                    year: 'numeric',
                    month: 'short',
                    day: 'numeric'
                });
            };

            // 处理搜索请求
            const handleSearch = async () => {
                searchError.value = '';
                hasSearched.value = true;

                // 表单验证
                const valid = await searchFormRef.value.validate();
                if (!valid) return;

                try {
                    isLoading.value = true;
                    searchResults.value = [];

                    // 使用配置的后端地址构建请求URL
                    const apiUrl = new URL(config.apiBaseUrl);
                    apiUrl.searchParams.set('callsign', searchForm.callsign);

                    // 发起请求
                    const response = await fetch(apiUrl.toString());
                    if (!response.ok) throw new Error(`HTTP error: ${response.status}`);

                    const data = await response.json();
                    searchResults.value = data.results || data; // 适配不同响应格式
                } catch (error) {
                    console.error('Search failed:', error);
                    searchError.value = 'Failed to fetch data. Please try again later.';
                } finally {
                    isLoading.value = false;
                }
            };

            return {
                searchForm,
                searchRules,
                searchFormRef,
                searchResults,
                isLoading,
                searchError,
                hasSearched,
                filterInput,
                isInputValid,
                formatDate,
                handleSearch
            };
        }
    })
        .use(ElementPlus)
        .mount('#app');
});